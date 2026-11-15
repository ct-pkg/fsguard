/*
 * FsGuardOps.shim.h -- char * 原语的 C 适配层（词法部分）。
 *
 * 这里只做纯词法操作，不访问文件系统：规范化、路径段边界、glob 匹配、
 * 缓冲区重叠检测。`normalize_to` 与 `check` 必须共用同一份段边界实现
 * （R-06 判据 5），所以两者都 include 本文件，而不是各写一遍。
 *
 * 规范化口径见 D-003：绝对路径在根处钳住 `..`，相对路径保留前导 `..`。
 */
#ifndef FSGUARD_OPS_SHIM_H
#define FSGUARD_OPS_SHIM_H

#ifndef _POSIX_C_SOURCE
#define _POSIX_C_SOURCE 200809L
#endif

#include <stddef.h>
#include <string.h>
#include <fnmatch.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <sys/stat.h>

/* check 的栈上规范化缓冲区上限；超长路径由调用方映射成 FS_ERR_IO。 */
#define FSGO_PATH_MAX 4096

/* walker 递归深度上限；超过由调用方拒绝（卡 K-1），不改需求口径。 */
#define FSGO_MAX_DEPTH 64

/* errno 在 C 里是宏，CT 侧看不到；经这个 shim 函数读。 */
static inline int fsgo_errno(void)
{
    return errno;
}

/*
 * char *::read_chunk 的实现（R-04）：按 offset 读最多 len 字节。
 * 返回实际字节数；0 = EOF；-1 = 错误，此时 *syserr 为 errno（参数非法时为 -1）。
 * 不补 NUL，二进制安全；每次重新打开文件（MVP 不做句柄缓存）。
 */
static inline int fsgo_read_chunk(const char *path, long long offset, char *buf,
                                  int len, int *syserr)
{
    int fd;
    int got;

    if (syserr != 0) *syserr = -1;
    if (path == 0 || buf == 0 || offset < 0 || len < 0) return -1;
    if (len == 0) return 0;

    fd = open(path, O_RDONLY);
    if (fd < 0) {
        if (syserr != 0) *syserr = errno;
        return -1;
    }
    if (lseek(fd, (off_t)offset, SEEK_SET) < 0) {
        if (syserr != 0) *syserr = errno;
        close(fd);
        return -1;
    }
    got = 0;
    while (got < len) {
        ssize_t n = read(fd, buf + got, (size_t)(len - got));
        if (n < 0) {
            if (syserr != 0) *syserr = errno;
            close(fd);
            return -1;
        }
        if (n == 0) break;
        got += (int)n;
    }
    close(fd);
    return got;
}

/* out 与 path 是否有字节重叠：重叠时规范化会边读边写，必须拒绝。 */
static inline int fsgo_overlap(const char *path, const char *out, int cap)
{
    unsigned long p;
    unsigned long o;
    unsigned long plen;
    unsigned long olen;

    if (path == 0 || out == 0) return 0;
    p = (unsigned long)path;
    o = (unsigned long)out;
    plen = (unsigned long)strlen(path) + 1;
    olen = (unsigned long)(cap > 0 ? cap : 0);
    if (o == p) return 1;
    if (o > p && o < p + plen) return 1;
    if (p > o && p < o + olen) return 1;
    return 0;
}

/* 词法规范化：成功返回 0；容量不足或重叠返回 -1 且 out[0] == 0。 */
static inline int fsgo_normalize(const char *path, char *out, int cap)
{
    int plen;
    int abs_path;
    int i;
    int n;
    int total;
    int pos;
    int k;
    int *starts;
    int *lens;

    if (path == 0 || out == 0 || cap <= 0) {
        if (out != 0 && cap > 0) out[0] = 0;
        return -1;
    }
    out[0] = 0;
    if (fsgo_overlap(path, out, cap)) return -1;

    plen = (int)strlen(path);
    if (plen > FSGO_PATH_MAX) return -1;

    starts = __builtin_alloca(sizeof(int) * (size_t)(plen + 1));
    lens = __builtin_alloca(sizeof(int) * (size_t)(plen + 1));

    abs_path = (path[0] == '/');
    i = 0;
    n = 0;
    while (i < plen) {
        int s;
        int len;
        while (i < plen && path[i] == '/') i++;
        s = i;
        while (i < plen && path[i] != '/') i++;
        len = i - s;
        if (len == 0) continue;
        if (len == 1 && path[s] == '.') continue;
        if (len == 2 && path[s] == '.' && path[s + 1] == '.') {
            if (n > 0 && !(lens[n - 1] == 2 && path[starts[n - 1]] == '.')) {
                n--;
            } else if (!abs_path) {
                starts[n] = s;
                lens[n] = 2;
                n++;
            }
            continue;
        }
        starts[n] = s;
        lens[n] = len;
        n++;
    }

    total = abs_path ? 1 : 0;
    for (k = 0; k < n; k++) {
        if (k > 0) total++;
        total += lens[k];
    }
    if (total == 0) total = 1; /* "." 或 "/" */
    if (total + 1 > cap) {
        out[0] = 0;
        return -1;
    }

    pos = 0;
    if (abs_path) out[pos++] = '/';
    for (k = 0; k < n; k++) {
        if (k > 0) out[pos++] = '/';
        memcpy(out + pos, path + starts[k], (size_t)lens[k]);
        pos += lens[k];
    }
    if (n == 0) {
        out[0] = abs_path ? '/' : '.';
        pos = 1;
    }
    out[pos] = 0;
    return 0;
}

/*
 * 路径段边界：1 = path 在 prefix 之下或相等，0 = 否。
 * 两侧必须是同一种路径（都绝对或都相对），否则 0（D-002）。
 */
static inline int fsgo_is_under(const char *path, const char *prefix)
{
    size_t n;

    if (path == 0 || prefix == 0) return 0;
    if ((path[0] == '/') != (prefix[0] == '/')) return 0;

    n = strlen(prefix);
    if (n == 0) return 0;
    while (n > 1 && prefix[n - 1] == '/') n--;

    if (strncmp(path, prefix, n) != 0) return 0;
    if (path[n] == 0) return 1;
    if (prefix[n - 1] == '/') return 1; /* prefix 是 "/" */
    return path[n] == '/';
}

/* deny 方言（D-005）：fnmatch + FNM_PATHNAME，`*` / `?` 不跨 `/`。 */
static inline int fsgo_match(const char *path, const char *pattern)
{
    if (path == 0 || pattern == 0) return 0;
    return fnmatch(pattern, path, FNM_PATHNAME) == 0;
}

/*
 * 唯一一份目录递归实现（R-07 / R-13 共用）。
 *
 * cb 返回非 0 → 立即中断并把该值原样返回。
 * filter 可选：返回 0 正常访问并递归；2 静默剪枝（不回调、不递归）；
 * -1 中止（错误码由调用方放在 ctx 里读）。
 * 返回 0 = 完成；>0 = 回调返回值；-1 = 错误（*syserr 为 errno，-1 表示非法参数）。
 */
typedef int (*fsgo_walk_cb)(char *entry, int is_dir, void *ud);
typedef int (*fsgo_walk_filter)(const char *path, int is_dir, void *ctx);

static inline int fsgo_walk_node(char *path, char *childbuf, int depth, int max_depth,
                                 fsgo_walk_cb cb, void *ud,
                                 fsgo_walk_filter filter, void *ctx, int *syserr)
{
    struct stat st;
    DIR *d;
    struct dirent *de;
    int is_dir;
    int rc;
    int f;

    if (lstat(path, &st) != 0) {
        if (syserr != 0) *syserr = errno;
        return -1;
    }
    is_dir = S_ISDIR(st.st_mode) ? 1 : 0;
    f = 0;
    if (filter != 0) f = filter(path, is_dir, ctx);
    if (f < 0) return -1;
    if (f == 2) return 0;

    rc = cb(path, is_dir, ud);
    if (rc != 0) return rc;
    if (!is_dir || depth >= max_depth) return 0;

    d = opendir(path);
    if (d == 0) {
        if (syserr != 0) *syserr = errno;
        return -1;
    }
    while ((de = readdir(d)) != 0) {
        int need;
        if (strcmp(de->d_name, ".") == 0 || strcmp(de->d_name, "..") == 0) continue;
        need = (int)strlen(path) + 1 + (int)strlen(de->d_name) + 1;
        if (need > FSGO_PATH_MAX) {
            closedir(d);
            if (syserr != 0) *syserr = ENAMETOOLONG;
            return -1;
        }
        snprintf(childbuf, FSGO_PATH_MAX, "%s/%s", path, de->d_name);
        rc = fsgo_walk_node(childbuf, childbuf + FSGO_PATH_MAX, depth + 1, max_depth,
                            cb, ud, filter, ctx, syserr);
        if (rc != 0) {
            closedir(d);
            return rc;
        }
    }
    closedir(d);
    return 0;
}

static inline int fsgo_walk(const char *root, fsgo_walk_cb cb, void *ud, int max_depth,
                            fsgo_walk_filter filter, void *ctx, int *syserr)
{
    char *bufs;
    size_t total;
    int rc;

    if (syserr != 0) *syserr = -1;
    if (root == 0 || cb == 0 || max_depth < 0) return -1;
    if (max_depth > FSGO_MAX_DEPTH) return -1;
    if (strlen(root) + 1 > FSGO_PATH_MAX) {
        if (syserr != 0) *syserr = ENAMETOOLONG;
        return -1;
    }
    total = (size_t)FSGO_PATH_MAX * (size_t)(max_depth + 2);
    bufs = malloc(total);
    if (bufs == 0) {
        if (syserr != 0) *syserr = ENOMEM;
        return -1;
    }
    strcpy(bufs, root);
    rc = fsgo_walk_node(bufs, bufs + FSGO_PATH_MAX, 0, max_depth, cb, ud, filter, ctx, syserr);
    free(bufs);
    return rc;
}

#endif
