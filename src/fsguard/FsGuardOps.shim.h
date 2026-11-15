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

/* check 的栈上规范化缓冲区上限；超长路径由调用方映射成 FS_ERR_IO。 */
#define FSGO_PATH_MAX 4096

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

#endif
