# 对 `ct-pkg/std` 的正式建议（可直接投递）

> 基线：`ct-pkg/std` `main@b04b7d6`、tag `v0.2.0`，本机 `ct` 0.53.0，Darwin/APFS。
> 证据来源：`docs/reviews/fsguard-std-overlap.md` §5–§6。本文只出建议，未改动 std 仓库。

## 0 投递方式

- **仓库**：`ct-pkg/std`（`git@github.com:ct-pkg/std.git`）。
- **形态：Issue，不是 PR。** 六条中有四条（1、2、3、5）会改公开 API 或语义，第 6 条是范围裁定，
  都需要维护者先拍板；直接开 PR 等于替维护者做了设计决定。
- 建议拆成 **5 个 issue**（第 2 条与第 6 条各一，其余各一），标题与正文按下面各节原样贴。
  - 第 1 条可在 issue 下附一个**不改签名**的 PR（`fopen` 后补目录/`ferror` 检查），作为修复候选。
  - 第 2、3、5 条先定签名，PR 等裁定后再开。
  - 第 4 条是纯增补，签名定了再 PR。
  - 第 6 条只需在 std 文档里记录「不做」的边界，不需要代码 PR。
- 不要把六条塞进一个 PR：其中三条要改签名，混在一起无法逐条回滚。

与 `fsguard-std-overlap.md` §6 的对应：1↔S-1，2↔S-2（原 S-6 并入），3↔S-3，4↔S-5，5↔S-7，6↔S-4。

---

## 1 `readFile` 读目录返回 0，调用方无法区分「空文件」与「目录」

**现象**：`char *::readFile(char *out, int cap)` 对目录返回 `0`。`fopen` 在目录上成功，
后续 `fread` 返回 0，实现没有检查目录性或 `ferror`，于是「读失败」被表达成「成功读到 0 字节」。
实测：`/tmp`（目录）`readFile` → `0`，与一个 0 字节普通文件完全同形。

**最小复现**：

```ct
import std::fs::Fs;

int main(void)
{
    char buf[64];
    int n = "/tmp".readFile(buf, sizeof(buf));   /* /tmp 是目录 */
    return n;                                     /* 实测返回 0 */
}
```

**期望行为**：目录返回 `-1`（与其它失败一致）；真正的 0 字节文件仍返回 `0`。
若维护者愿意引入可区分错误，也可返回专门的错误值，但不应再与空文件同值。
不改签名，不动 `cap` 含 NUL 的既有约定。

**影响面**：任何把 `readFile` 结果当文件内容的上层都会把目录静默当成空文件——配置加载读到空串、
拷贝工具产出 0 字节副本、存在性判断被绕过。错误静默，调用方无法自行发现。

**优先级**：优先。

---

## 2 `writeFile` 按 `strlen` 写，含 NUL 的数据被静默截断

**现象**：`char *::writeFile(const char *data)` 没有长度参数，实现按 `strlen(data)` 写。
实测写入 `a\0b`（3 字节缓冲）后落盘 1 字节，返回 `0`（成功）。

**最小复现**：

```ct
import std::fs::Fs;

int main(void)
{
    char data[3];
    data[0] = 'a';
    data[1] = 0;
    data[2] = 'b';
    "/tmp/fsg-nul.bin".writeFile(data);   /* 返回 0（成功） */
    return 0;                             /* stat 显示文件只有 1 字节 */
}
```

**期望行为**：二选一，并且写进文档与返回面：
1. 增加带长度的写入，如 `writeFile(const char *data, int len)`；或
2. 保持签名，但在文档与 issue 回复里明确指向 `std::io::File::write(buf, n)`，并说明
   `writeFile` 只接受以 NUL 结尾的文本。

当前「返回成功 + 静默截断」不能接受，因为调用方没有任何信号。

**影响面**：协议帧、序列化数据、加密块等二进制内容落盘被截断，且返回码是成功；
后续读取方只会看到短文件，错误被推迟到业务层。

**优先级**：优先。

---

## 3 `std::io` 不暴露 errno，失败无法分类

**现象**：`char *::open(mode)` 失败返回 `NULL`，`IoFile::read/write` 失败返回 `-1`；
`errno` 是 C 宏，CT 侧不可见，标准库也没有访问器。实测「文件不存在」与「权限不足」
在 CT 侧只能得到同一个 `NULL`。

**最小复现**：

```ct
import std::io::File;

int main(void)
{
    IoFile *missing = "/tmp/fsg-does-not-exist".open("r");
    IoFile *denied  = "/tmp/fsg-chmod-000".open("r");  /* 夹具：chmod 000 */
    return (missing == 0) + (denied == 0);             /* 实测 2，两者不可区分 */
}
```

**期望行为**：在 `std::io`（或 `std::fs`）加一个 errno 访问器，例如
`int lastErrno(void)`，由 C shim 读取 `errno` 后返回 `int`。
不要求错误码枚举、不要求字符串化，只要求能把常见失败（`ENOENT` / `EACCES` / `EISDIR` /
`ENOTDIR`）区分开。

**影响面**：上层只能把失败统一报成「失败」，无法决定重试、提示权限还是当作不存在；
任何需要错误分类的包都只能自写 C shim（fsguard 目前就是这样绕的）。

**优先级**：次之（存在绕法，但每个消费者都要重复一次）。

---

## 4 补 `mkdir` / `remove` / `rename`

**现象**：`std/fs/README.md` §1 明写不提供目录创建、删除与重命名；包内没有对应公开方法。
核对方式：对 `std/fs` 做 `grep -n 'mkdir\|remove\|rename'`，命中数为 0。

**最小复现**：

```ct
import std::fs::Fs;

int main(void)
{
    /* 想写「临时文件 + rename 原子替换」，std 里没有 rename： */
    "/tmp/fsg-a.txt".writeFile("new");
    /* 等价于 rename("/tmp/fsg-a.txt", "/tmp/fsg-b.txt") 的公开方法不存在 */
    return 0;
}
```

**期望行为**：补三个方法，风格与现有 `std::fs` 一致（成功 `0`，失败 `-1`）：
`mkdir(const char *path, int mode)`、`remove(const char *path)`、`rename(const char *from, const char *to)`。
签名先由维护者确认，尤其是 `remove` 是否递归。

**影响面**：原子替换、清理临时目录、重排产物都只能落回 C API，破坏「std 内可完成基本文件操作」
的一致性；消费者要么写 shim，要么直接 include `<stdio.h>`。

**优先级**：次之。

---

## 5 `IoFile` 没有 seek / offset 读，只能顺序读

**现象**：`std::io::File` 只有 `read` / `write` / `close`；没有 `seek` / `tell`，也没有 offset 参数。
读第 3 个 100 字节块只能从头读掉前 200 字节。

**最小复现**：

```ct
import std::io::File;

int main(void)
{
    IoFile *f = "/tmp/fsg-big.bin".open("r");
    char buf[100];
    f->read(buf, 100);    /* 0..99 */
    f->read(buf, 100);    /* 100..199 */
    /* 想直接读 offset=500 的 100 字节：没有 API，只能再读 300 字节丢掉 */
    f->close();
    return 0;
}
```

**期望行为**：增加 `IoFile::seek(long long offset, int whence)`，或
`IoFile::readAt(long long offset, char *buf, int len)`；offset 类型用 `long long` / `int64_t`，
公开面不出现 `long`。失败返回 `-1`，成功返回新位置或读到的字节数。

**影响面**：大文件分块、断点续读、随机访问全部退化为整读或自写 C；
`std::fs` 的整文件 `readFile` 也无法替代，因为它要求缓冲能装下整个文件。

**优先级**：优先。

---

## 6 反向结论：路径规范化 / 段边界判定 / 递归遍历**不建议**进 `std`

**现象**：这三类语义目前由 `ct-fsguard` 提供；`std` 的定位是「整文件 / 单层原语」
（`std/fs/README.md` §1、§8 已明确不提供）。

**最小复现**（说明三者都不是「再加一个函数」）：

```ct
/* 路径规范化不是字符串函数：`..` 的钳制规则依赖「绝对还是相对」 */
"src/../a.c"      -> "a.c"
"/tmp/../../../etc" -> "/etc"     /* 绝对路径在根处钳住 */
"../etc"          -> "../etc"     /* 相对路径保留前导 .. */

/* 段边界不是前缀： */
"/workspace/src2/a.c".startsWith("/workspace/src") == 1   /* 字符串前缀会误判 */
/* 需要的是按 `/` 分段比较 */

/* 递归遍历不只是「多一层 list」：需要深度上限、回调中止、deny 剪枝、fail-closed */
```

**期望行为（反向）**：保持现状，不把三类语义加进 `std`。理由：
1. 规范化与段边界是**策略前件**：`..` 钳制、绝对/相对、`\` 是否当分隔符，都是包级裁定
   （fsguard 的 D-002 / D-003 / D-007）。一旦进 std 就冻结成语言级语义，所有消费者被迫接受同一种策略。
2. 递归遍历需要深度参数、回调中止、deny 剪枝与 fail-closed，这些是策略 + 错误码；
   `std` 没有错误码面（见第 3 条），放进去会同时绑死遍历语义与错误语义。
3. `std` 已经给了够用的积木：`std::str` 的 `find` / `slice` / `copy`、`std::fs` 的 `list`。
   组合这些积木是包层的事，不是 `std` 的事。

**影响面**：若反向采纳（即塞进 std），fsguard 的 `normalize_to` / `is_under` / `walk` 会变成
重复 API；std 还要新增策略参数与错误码，违背「薄层」定位，且每加一条规则都是一次破坏性变更。

**优先级**：次之（结论是「不做」；建议在 std 的 README 里把这条边界写成明文，避免后续重复提案）。

---

## 7 一句话汇总

`std` 的四个整文件/单层原语有两个静默错误（读目录返 0、按 `strlen` 写）和一个能力缺口
（无 `seek`），这三条最该先修；errno、`mkdir/remove/rename` 次之；路径规范化、段边界与递归遍历
应当留在包层，不进 `std`。
