# fsguard

`std::fs` 之上的词法路径策略层：`char *` 上的无状态原语 + `FsGuard` 有状态检查。

- 状态：PH-01/PH-02/PH-03 已收口；PH-04 前半进行中（文档口径、R-15、R-16、FSR-02/03/04），后半挂起（R-01 判据 2/3、R-03、R-02 限定名、R-17 Linux 记录），前半全绿也不得收口。
- 边界：**这是词法策略层，不是安全边界；不解析符号链接、不防 TOCTOU。**
- 门禁：`bash tools/check.sh all`。

## 用法

```ct
import fsguard::FsGuard;
import fsguard::FsGuardOps;

char norm[256];
"src/../a.c".normalize_to(norm, 256);          // "a.c"
if ("src/a.c".is_under("/workspace/src")) { }   // 段边界，不是字符串前缀

FsGuard *g = fsguard::fsguard_new("/workspace");
g->allow_prefix("/workspace/src");
g->max_depth(8);
if (g->check("/workspace/src/a.c") == FS_OK) { }

char buf[1024];
g->read_file("/workspace/src/a.c", buf, sizeof(buf));
g->write_file("/workspace/src/out.bin", data, len);
g->read_chunk("/workspace/src/a.c", 0, buf, 100);
g->walk("/workspace/src", on_entry, 0);
delete g;
```

## 契约

1. `last_error()` 返回只读借用；`FsError *` 及其 `path`/`message` 在**下一次** `FsGuard` 操作后失效，不得跨操作持有；每次公开操作开头清空错误，`clear_error()` 后返回 NULL。
2. `write_file` 原地截断写（D-006）：成功返回 `len`；失败只保证错误码，**目标文件内容未定义**。需要原子性请自己写临时路径再 `rename`。
3. `walk` 的 `entry` 是借用，生命周期到回调返回为止：
   - 跨回调保留必须显式复制（`strdup` 或等价）；
   - 回调不得 `free(entry)`；
   - `ud` 归注册方所有；
   - 遍历返回后，旧 `entry` 裸指针可能悬垂；
   - 不承诺遍历顺序。
4. `normalize_to` 的 `out` 与输入重叠是错误用法，实现会返回 -1 并清空 `out`（D-008）。

## 与 `ct-pkg/std` 的分工

fsguard 通过 `ct.pkg` 的 `dep = std@0.3.2` 与提交在库的 `ct.lock` 引入 std（D-014），
两者可在同一编译单元共存，`char *` 方法名不冲突（D-011 的分工结论）。分工与语义差异如下，**不要混用**：

| 能力 | 提供方 | 说明 |
| --- | --- | --- |
| 存在性、整文件便捷读写、单层列目录 | `std::fs` | `exists` / `readFile` / `writeFile` / `list`；失败统一 `-1`，无 errno |
| 策略检查、错误码、二进制读写、offset 读、递归遍历 | fsguard | 需要 `FS_ERR_*` 分类与 `len` 语义，std 的返回面表达不了 |

- `std::fs.readFile` 读目录返回 0（把目录当空文件）；fsguard 返回 `FS_ERR_IS_DIR`。
- `std::fs.readFile` / `writeFile` 失败统一 `-1`；fsguard 返回 `FS_ERR_NOT_FOUND` / `FS_ERR_PERMISSION` / `FS_ERR_IS_DIR` 等。
- `std::fs.writeFile` 按 `strlen` 写、不能含 NUL；`write_file` 按 `len` 写二进制。
- `std::fs.list` 单层、用 `\n` 拼接、不区分类型、不递归；`walk` 递归、带 `is_dir`、可剪枝。
- std 不提供 `normalize_to` / `is_under` / 段边界；这些由 fsguard 提供。
- 两边都是 POSIX 取向：`std::fs.list` 在 Windows 不可用，fsguard 的 `walk` 同样依赖 `opendir`。

## 能力对照表

本表与实现一一对应（R-16）：`fsguard` 列出的符号都真实存在；标「不提供」的能力只由 `std` 承担，
fsguard 不在 `char *` 上另开同名方法。

| 能力 | fsguard 符号 | std 符号 | 归属 |
| --- | --- | --- | --- |
| 路径规范化 | `char *::normalize_to` | 无（`std::str` 只有字节切分） | fsguard |
| 段边界判定 | `char *::is_under` | 无（`startsWith` 是字符串前缀） | fsguard |
| 按 offset 分块读 | `char *::read_chunk` / `FsGuard::read_chunk` | 无（`IoFile` 无 `seek`） | fsguard |
| 递归遍历 | `char *::walk` / `FsGuard::walk` | `list`（单层、`\n` 拼接、无类型） | fsguard |
| 策略准入判定 | `FsGuard::check` | 无 | fsguard |
| 带错误码的整文件读 | `FsGuard::read_file` | `readFile`（失败统一 `-1`，目录返 0） | fsguard |
| 按长度写（二进制安全） | `FsGuard::write_file` | `writeFile`（按 `strlen`） | fsguard |
| 策略配置 | `FsGuard::allow_prefix` / `deny_pattern` / `max_depth` | 无 | fsguard |
| 错误对象 | `FsGuard::last_error` / `has_error` / `clear_error` | 无 | fsguard |
| 句柄构造 | `fsguard_new` | 无 | fsguard |
| 存在性判断 | 不提供 | `exists` | std |
| 单层列目录 | 不提供 | `list` | std |
| 整文件便捷读写 | 不提供 | `readFile` / `writeFile` | std |
| 顺序流式 I/O | 不提供 | `open` / `read` / `write` / `close` | std |
| 字符串与容器工具 | 不提供 | `std::str` / `Vec` / `Map` / `Arena` | std |

`char *` 上本包只占四个方法名（`normalize_to` / `is_under` / `read_chunk` / `walk`），
与 std 的 22 个名字交集为空（D-011）；同名时用 `FsGuardOps::method(...)` 限定调用。

## 文档

- [提案原文](docs/proposal.md)
- [需求分析](docs/requirements.md)
- [落地路线](docs/planning/fsguard-roadmap.md)
- [决策记录](docs/decisions/README.md)
- [与 std 的符号级对照](docs/reviews/fsguard-std-overlap.md)
- [需求状态](docs/acceptance/fsguard-status.md)
