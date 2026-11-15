# fsguard 需求定稿状态（D-001…D-010 后）

> 本文件只记录状态口径，不改 `requirements.md` / `design.md` 正文。  
> 静态校验：`bash tools/check.sh g4-static`；锚点校验：`bash tools/check.sh g5-anchor`。

## 1 结论

**PH-01/PH-02/PH-03 已收口：遍历与策略已落地。** 需求口径上 17 条中 15 条可验收、2 条部分可验收（R-02/R-17）、0 条不可验收。剩余两项均已写明缺项与归属：R-02 缺 `FsErrCode::FS_ERR_*` 限定名（ct 0.53.0 仍不可表达，H-2 → PH-04）、R-17 缺 Linux LSan 实测记录回填（→ PH-04 / Linux CI）。H-7 已由 D-010 关闭。

## 2 威胁模型五处（承接 FSR-02…06）

| 威胁 | 当前口径 | 状态 |
| --- | --- | --- |
| TOCTOU | 词法 `check` 与 `open` 分离，不防护 | 非目标（D-012） |
| 硬链接 | 不比较 inode/nlink，不防护 | 非目标（D-012） |
| 挂载点/绑定 | 不比较 `st_dev`，不防护；需特权 | 非目标（D-012） |
| 超长路径 | `FSGO_PATH_MAX=4096` 已冻结；超长 → `FS_ERR_IO`（`r14`） | 已收口 |
| 符号链接环 | `ELOOP → FS_ERR_IO`（D-009）；环用例在 `r14` | 已收口 |

## 3 未决项

| 项 | 状态 | 影响 |
| --- | --- | --- |
| Q-2 | 已裁（D-006） | `write_file` 原地截断写、失败不回滚 |
| Q-3 | 已裁（D-003） | R-05/R-06/R-09 的 `..` 规则 |
| Q-4 | 已裁（D-004） | R-07/R-13 的 `char *::walk` 三参数 |
| Q-5 | 已裁（D-001） | R-02/R-04/R-08/R-10/R-14 的非法参数码 |
| Q-6 | 已裁（D-002） | R-06/R-09 的绝对 root + 相对输入 |
| Q-7 | 已裁（D-005） | R-10/R-13 的 deny 最小方言 |
| `FS_ERR_NOT_DIR` | 已收口（D-009） | `ENOTDIR → NOT_DIR`，R-02/R-14 可验收 |
| `ELOOP` | 已收口（D-009） | 归 `FS_ERR_IO`，PH-02 有环用例 |
| H-7 | 已关闭（D-010） | R-11 判据 3 改为可核对条款，不再挂「部分」 |
| Q-1 / H-3 | 已裁（D-012） | 放弃「沙箱 / 安全边界」主张，只做词法策略层；TOCTOU/硬链接/挂载点/超长路径/符号链接环不在防护范围 |
| LSan | 记录未回填 | R-17 判据 5 待 Linux 实测记录；`g7-lsan-record` 当前红 |

## 4 R 状态

| R | 状态 | 依据 |
| --- | --- | --- |
| R-01 | 可验收 | 包形态判据已定 |
| R-02 | 部分 | 10 码与 `NOT_DIR` 已收口（D-009）；**缺项**：限定名 `FsErrCode::*` 在 ct 0.44.1 报 `qualified type names are not supported`（H-2）；**归属 PH-04**，触发条件为 ct 升级后复跑 `test/fsguard/r02_errors.ct` 的限定名用例 |
| R-03 | 可验收 | 命名共存判据已定 |
| R-04 | 可验收 | Q-5 已裁（D-001），负 offset→`FS_ERR_IO` |
| R-05 | **可验收** | Q-3（D-003）与重叠拒绝（D-008）已裁；`g3-ph01 r05` 绿 |
| R-06 | **可验收** | Q-6（D-002）与判据 1 示例（D-007）已裁；`g3-ph01 r06` 绿 |
| R-07 | **可验收** | Q-4（D-004）已裁；根缺失与借用契约由 `g3-ph03 r07` 覆盖 |
| R-08 | 可验收 | Q-5 已裁（D-001），setter 非法参数只返回 NULL |
| R-09 | 可验收 | Q-6 已裁（D-002），相对输入拒绝；Q-3 已由 D-003 关闭 |
| R-10 | **可验收** | Q-7（D-005）、Q-5（D-001）已裁；`g3-ph03 r10` 覆盖默认深度/覆盖/空串 |
| R-11 | **可验收** | 判据 3 由 D-010 改为可核对条款；`g3-ph02 r11` 与新门禁清错计数覆盖 |
| R-12 | **可验收** | Q-2 已裁（D-006）：失败只断言错误码，成功断言 `len`；`g3-ph02 r12` 绿 |
| R-13 | **可验收** | `g3-ph03 r13` 覆盖剪枝、root 越界、fail-closed 与共享 walker |
| R-14 | **可验收** | `ENOTDIR → NOT_DIR`、`ELOOP → IO`（D-009）；`g3-ph02 r14` 绿 |
| R-15 | 可验收 | POSIX 边界已定 |
| R-16 | 可验收 | `std::fs` 零改动判据已定 |
| R-17 | 部分 | 判据 1–4 本机可执行（运行时夹具、门禁覆盖、集合排序、ASan）；**缺项**：判据 5 的 LSan 结论只能由 Linux 给出，当前**缺 Linux 实测记录回填**（`g7-lsan-record` 红）；**归属 PH-04 / Linux CI**：Linux 跑 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 后按 `docs/reviews/fsguard-lsan-linux.md.tmpl` 回填 |

## 5 锚点说明

- **R-05**：Q-3 按 **D-003** 冻结为「绝对钳住、相对保留前导 `..`」；`requirements.md:90-101` 九行表即冻结口径，正文未动。
- **R-06**：判据 1 的相对示例由 **D-007** 改为绝对路径；`requirements.md:116` 正文未动，验收以 D-007 为准。
- **R-07**：`char *::walk` 按 **D-004** 冻结为三参数；`requirements.md:129` 的「三参数调用示例」笔误拟改为「两参数」。
- **R-10**：deny 方言按 **D-005** 冻结为最小集；`requirements.md:181` 正文未动。
- **R-04/R-08**：Q-5 按 **D-001** 冻结为「不新增第 11 个错误码」；正文未动。

## 6 PH-01 实施状态

| 项 | 状态 | 证据 |
| --- | --- | --- |
| `FsErrCode` 10 码 | 已实现 | `bash tools/check.sh g3-ph01 r02`（11 checks） |
| `normalize_to` | 已实现 | `bash tools/check.sh g3-ph01 r05`（13 checks） |
| `is_under` | 已实现 | `bash tools/check.sh g3-ph01 r06`（9 checks） |
| `FsGuard::check` + `last_error` | 已实现 | `bash tools/check.sh g3-ph01 r09`（27 checks） |

门禁红绿原始输出见 `docs/reviews/fsguard-ph01-evidence.md`。

## 6.1 PH-02 实施状态

| 项 | 状态 | 证据 |
| --- | --- | --- |
| `char *::read_chunk` | 已实现 | `bash tools/check.sh g3-ph02 r04`（8 checks） |
| `FsGuard` 读写 | 已实现 | `bash tools/check.sh g3-ph02 r12`（16 checks） |
| 生命周期 / setter | 已实现 | `bash tools/check.sh g3-ph02 r08`（15 checks） |
| `last_error` 全操作 | 已实现（判据 3 由 D-010 关闭 H-7） | `bash tools/check.sh g3-ph02 r11`（16 checks） |
| errno 映射 | 已实现（D-009） | `bash tools/check.sh g3-ph02 r14`（6 checks） |
| ASan 门禁 | 已修复（看门狗） | `bash tools/check.sh g7-asan` |

门禁红绿原始输出见 `docs/reviews/fsguard-ph02-evidence.md`。

## 6.2 PH-03 实施状态

| 项 | 状态 | 证据 |
| --- | --- | --- |
| 唯一递归 walker | 已实现 | `g3-ph03 all` 校验 `fsgo_walk_node` 全仓唯一 |
| `char *::walk`（R-07） | 已实现 | `bash tools/check.sh g3-ph03 r07`（17 checks） |
| 策略 setter / 默认深度（R-10） | 已实现 | `bash tools/check.sh g3-ph03 r10`（13 checks） |
| `FsGuard::walk`（R-13） | 已实现 | `bash tools/check.sh g3-ph03 r13`（10 checks） |
| R-11 判据 3（D-010） | 已收口 | `bash tools/check.sh g3-ph02 r11` + 清错计数 6 |
| ASan 门禁 | 绿 | `bash tools/check.sh g7-asan` |

门禁红绿原始输出见 `docs/reviews/fsguard-ph03-evidence.md`。

## 7 泄漏与平台

- Darwin：`bash tools/check.sh g7-leak` 打印 SKIP（原因 + Linux 命令 + 回填路径）并以 **rc=0** 结束；SKIP 不是泄漏结论。
- 泄漏结论只认 Linux 记录：`bash tools/check.sh g7-lsan-record` 校验 `docs/reviews/fsguard-lsan-linux.md` 含 `host: Linux …`、确切命令与 `PASS: g7-leak: Linux ASan+LSan caught the leak` 原文；缺记录或占位符判红。**当前红，等 Linux 回填**。
- Linux 补跑：`ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`，按 `docs/reviews/fsguard-lsan-linux.md.tmpl` 回填后再跑 `g7-lsan-record`。
- 本机可跑：`bash tools/check.sh g7-asan`（干净夹具 rc=0，UAF 被捕获；已加看门狗，`asan_uaf` 不退出也会被收口）。
- `all`：Darwin 上 `g7-leak` 为 rc=0，`all` 因此 rc=0；SKIP 不是结论，`g7-lsan-record` 需单独跑，**当前红**（防呆项，PH-04 收口前必须转绿）。

## 8 与 `ct-pkg/std` 的关系（D-011）

- 已按 `ct get` / `ct install` 核对 `std` 0.2.0（tag `v0.2.0`，`b04b7d6`）：`std::fs` 只有 `exists` / `readFile` / `writeFile` / `list`，`std::io` 只有 `open` / `read` / `write` / `close`，`std::str` 只有字节级方法；**没有**路径规范化、段边界、递归遍历、offset 读、errno。
- 符号级对照见 `docs/reviews/fsguard-std-overlap.md`：fsguard 的 12 个公开符号与 std 零重复；`read_file` / `write_file` 同形但不可替代（std 目录读返回 0、失败统一 `-1`、按 `strlen` 写）。按「直接改实现」逐函数复核后**可删 0 行**。
- 结论（D-011）：不新增 `std` 依赖、不拆 path 包；std 缺失的语义继续由 fsguard 提供；对 std 的建议只记录、不改 std 仓库。硬依赖 std 需要每个消费者与门禁都持有 `vendor/std`，而 `vendor/std` 不进版本库，构建会失去自足性。
- 语义差异同时写进 `README.md` 与 `docs/acceptance/fsguard-commands.md` 的附表，门禁 `g0-decisions` 核对这两处存在。
- 由安装暴露的包形态缺口：`ct install` 只打印 `-I vendor/<包名>`，而 fsguard 的单元在 `src/fsguard/`，消费者实测报 `cannot resolve import 'fsguard/FsGuard'`；归 **PH-04**。
