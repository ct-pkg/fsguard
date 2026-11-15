# fsguard

`std::fs` 之上的词法路径策略层：`char *` 上的无状态原语 + `FsGuard` 有状态检查。

- 状态：PH-01/PH-02/PH-03 已收口；下一相 PH-04（包形态/平台/门禁）。
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

fsguard 不依赖 std（`ct.pkg` 零 `dep`），两者可在同一编译单元共存，`char *` 方法名不冲突
（D-011）。分工与语义差异如下，**不要混用**：

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

## 文档

- [提案原文](docs/proposal.md)
- [需求分析](docs/requirements.md)
- [落地路线](docs/planning/fsguard-roadmap.md)
- [决策记录](docs/decisions/README.md)
- [与 std 的符号级对照](docs/reviews/fsguard-std-overlap.md)
- [需求状态](docs/acceptance/fsguard-status.md)
