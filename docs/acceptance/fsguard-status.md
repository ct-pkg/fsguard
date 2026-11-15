# fsguard 需求定稿状态（D-001…D-009 后）

> 本文件只记录状态口径，不改 `requirements.md` / `design.md` 正文。  
> 静态校验：`bash tools/check.sh g4-static`；锚点校验：`bash tools/check.sh g5-anchor`。

## 1 结论

**PH-01 已收口，PH-02 实施中：读写、错误面与生命周期已落地。** 需求口径上 17 条中 14 条可验收、3 条部分可验收（R-02/R-11/R-17）、0 条不可验收。剩余未决项：R-02 的限定名不可表达（H-2）、R-11 判据 3 不可稳定判定（H-7）、macOS LSan 降级（R-17）。

## 2 威胁模型五处（承接 FSR-02…06）

| 威胁 | 当前口径 | 状态 |
| --- | --- | --- |
| TOCTOU | 词法 `check` 与 `open` 分离，不防护；负例待实现 | 未收口 |
| 硬链接 | 不比较 inode/nlink，不防护；`ln` 越界负例待实现 | 未收口 |
| 挂载点/绑定 | 不比较 `st_dev`，不防护；需特权，不能进普通 CI | 未收口 |
| 超长路径 | `PATH_MAX` 未冻结，`ENAMETOOLONG` 映射未定 | 未收口 |
| 符号链接环 | `ELOOP` 未归类，环用例待实现 | 未收口 |

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
| LSan（macOS） | 平台化降级 | R-17 本机不能完整自证 |

## 4 R 状态

| R | 状态 | 依据 |
| --- | --- | --- |
| R-01 | 可验收 | 包形态判据已定 |
| R-02 | 部分 | 10 码与 `NOT_DIR` 已收口（D-009）；限定名 `FsErrCode::*` 在 ct 0.44.1 不可表达（H-2） |
| R-03 | 可验收 | 命名共存判据已定 |
| R-04 | 可验收 | Q-5 已裁（D-001），负 offset→`FS_ERR_IO` |
| R-05 | **可验收** | Q-3（D-003）与重叠拒绝（D-008）已裁；`g3-ph01 r05` 绿 |
| R-06 | **可验收** | Q-6（D-002）与判据 1 示例（D-007）已裁；`g3-ph01 r06` 绿 |
| R-07 | **可验收** | Q-4 已裁（D-004）；FSR-15 根缺失为 PH-03 补充判据 |
| R-08 | 可验收 | Q-5 已裁（D-001），setter 非法参数只返回 NULL |
| R-09 | 可验收 | Q-6 已裁（D-002），相对输入拒绝；Q-3 已由 D-003 关闭 |
| R-10 | **可验收** | Q-7 已裁（D-005），Q-5 已裁（D-001） |
| R-11 | 部分 | 判据 3「旧指针内容已变」不是稳定后条件（H-7）；其余判据由 `g3-ph02 r11` 覆盖 |
| R-12 | **可验收** | Q-2 已裁（D-006）：失败只断言错误码，成功断言 `len`；`g3-ph02 r12` 绿 |
| R-13 | 可验收 | 遍历判据与 fail-closed 已定；deny 方言由 D-005 冻结 |
| R-14 | **可验收** | `ENOTDIR → NOT_DIR`、`ELOOP → IO`（D-009）；`g3-ph02 r14` 绿 |
| R-15 | 可验收 | POSIX 边界已定 |
| R-16 | 可验收 | `std::fs` 零改动判据已定 |
| R-17 | 部分 | macOS LSan 降级，泄漏门禁交 Linux CI |

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
| `last_error` 全操作 | 已实现（判据 3 记 H-7） | `bash tools/check.sh g3-ph02 r11`（16 checks） |
| errno 映射 | 已实现（D-009） | `bash tools/check.sh g3-ph02 r14`（6 checks） |
| ASan 门禁 | 已修复（看门狗） | `bash tools/check.sh g7-asan` |

门禁红绿原始输出见 `docs/reviews/fsguard-ph02-evidence.md`。

## 7 泄漏与平台

- Darwin：`bash tools/check.sh g7-leak` 只能 `DEFERRED rc=3`；PH-01/PH-02 的「无内存泄漏」记 **待 Linux 补跑**，不得记通过。
- Linux 补跑命令：`ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`。
- 本机可跑：`bash tools/check.sh g7-asan`（干净夹具 rc=0，UAF 被捕获；已加看门狗，`asan_uaf` 不退出也会被收口）。
