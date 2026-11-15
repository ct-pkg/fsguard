# PH-02 卡：读写、错误面与生命周期

id: PH-02
status: in-progress
opened: 2026-11-15
spec-version: 1.9.0
version-minor: 2
roadmap: docs/planning/fsguard-roadmap.md

## 目标

把 `FsGuard` 从「只能判定」变成「能读写」：`read_file` / `write_file` / `read_chunk`、`last_error` 全操作契约、生命周期与 setter、`errno` 映射。Q-2 在开卡时已裁（D-006），不拖到收口。

## 范围

**做什么**

- R-04 `char *::read_chunk`：offset / EOF / 负参数 / 二进制安全。
- R-08 `FsGuard` 生命周期：`fsguard_new`、`impl Drop`、setter 链式与非法参数。
- R-11 `last_error` / `clear_error` 契约：每次公开操作开头清错。
- R-12 `read_file` / `write_file` / `read_chunk` 包装：先 `check` 后 I/O。
- R-14 `errno → FS_ERR_*` 唯一映射与 `fsguard_strdup`。

**不做什么**

- `walk`（PH-03）、包形态与平台分层（PH-04）。
- 原子写（R-12 非目标，D-006 保留）。
- 不修改 `docs/requirements.md` 与 `docs/design.md` 正文。

## 交付物清单

| # | 路径 | 内容 |
| --- | --- | --- |
| 1 | `docs/decisions/D-006.md` … `D-009.md` | Q-2、H-3、H-4、H-8 的裁定 |
| 2 | `src/fsguard/FsGuardOps.shim.h` | `read_chunk` 原语（`open`/`lseek`/`read`） |
| 3 | `src/fsguard/FsGuard.h.ct` | `read_file` / `write_file` / `read_chunk` / `max_depth` / `fsguard_errno_to_code` |
| 4 | `src/fsguard/FsGuardOps.m.ct` | `read_chunk` 的 `map trait` |
| 5 | `test/fsguard/r04_read_chunk.ct` | R-04 判据 1–5 |
| 6 | `test/fsguard/r08_lifecycle.ct` | R-08 判据 1–5 |
| 7 | `test/fsguard/r11_error.ct` | R-11 判据 1/2/4/5/6（判据 3 见 H-7） |
| 8 | `test/fsguard/r12_rw.ct` | R-12 判据 1–7 |
| 9 | `test/fsguard/r14_errno.ct` | R-14 判据 2（四类 + ELOOP） |
| 10 | `tools/check.sh` | `g3-ph02`、`g7-asan` 看门狗、`g1-phase-card` 支持多相 |
| 11 | `docs/reviews/fsguard-ph02-evidence.md` | 红绿原始输出 |

## 任务清单

| ID | 交付物 | 验收命令 | effort | 回滚 |
| --- | --- | --- | --- | --- |
| T-01 | D-006…D-009 裁定与需求侧口径 | `bash tools/check.sh g0-decisions` | S | `git revert <T-01 实现提交>` |
| T-02 | `char *::read_chunk` 原语 | `bash tools/check.sh g3-ph02 r04` | M | `git revert <T-02 实现提交>` |
| T-03 | `FsGuard` 读写与 `check` 前置 | `bash tools/check.sh g3-ph02 r12` | M | `git revert <T-03 实现提交>` |
| T-04 | 生命周期、setter、`max_depth` | `bash tools/check.sh g3-ph02 r08` | S | `git revert <T-04 实现提交>` |
| T-05 | `last_error` 全操作契约 | `bash tools/check.sh g3-ph02 r11` | S | `git revert <T-05 实现提交>` |
| T-06 | `g7-asan` 看门狗 | `bash tools/check.sh g7-asan` | S | `git revert <T-06 实现提交>` |
| T-07 | `g3-ph02` 接入与全量绿 | `bash tools/check.sh g3-ph02` | S | `git revert <T-07 实现提交>` |

每条任务的验收命令只验本任务交付物，不同时覆盖两条退出判据（6.6 T-5）。

## 退出判据

| # | 判据 | 命令 | 二值结果 |
| --- | --- | --- | --- |
| E-1 | Q-2、H-3、H-4、H-8 均有已裁 D 记录且 13 字段齐全 | `bash tools/check.sh g0-decisions` | rc=0 |
| E-2 | R-04：分块读、EOF、负参数、二进制安全 | `bash tools/check.sh g3-ph02 r04` | rc=0 |
| E-3 | R-12：返回值、容量边界、越界先 check、错误映射 | `bash tools/check.sh g3-ph02 r12` | rc=0 |
| E-4 | R-08：root 规范化、NULL root、链式 setter、非法参数不改状态 | `bash tools/check.sh g3-ph02 r08` | rc=0 |
| E-5 | R-11：操作开头清错、失败置错、`clear_error` | `bash tools/check.sh g3-ph02 r11` | rc=0 |
| E-6 | R-14：四类 errno + ELOOP；全包只有一个映射函数 | `bash tools/check.sh g3-ph02 r14` | rc=0 |
| E-7 | ASan 门禁可重复执行（看门狗），不再依赖外部 kill | `bash tools/check.sh g7-asan` | rc=0 |
| E-8 | 本相全量 | `bash tools/check.sh g3-ph02` | rc=0 |

任务清单每项可独立验收（6.6 T-6）：上表每条 E 只对应一条任务，任务验收命令只指向本任务交付物，不借「整相全绿」。

## 三条边界

**B-1 Q-2 已在开卡时裁掉（D-006）。** `write_file` 原地截断写、失败不回滚；失败后目标内容未定义并在文档与判据明示；原子写仍是非目标。PH-02 收口不再等 Q-2。

**B-2 H-3 / H-4 落到需求侧。** D-007 把 R-06 判据 1 的两个示例改成绝对路径；D-008 把 R-05 判据 4 改成「重叠必须拒绝」。两条都同步进 `docs/acceptance/fsguard-commands.md` 与 `fsguard-status.md`，不再只躺在 PH-01 证据里。

**B-3 泄漏门禁仍是 deferred。** `g7-leak` 在 Darwin 只能 `DEFERRED rc=3`；PH-02 的「无内存泄漏」记「待 Linux 补跑」，命令 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`。ASan 门禁本轮修好（H-6），但 ASan ≠ LSan，不得互相顶替。

## 依赖

- PH-01 已收口：`FsErrCode`、`normalize_to`、`is_under`、`check`。
- D-001（Q-5 非法参数口径）、D-002（相对输入拒绝）、D-006…D-009。
- ct 0.44.1（`~/.local/bin/ct`）；POSIX `open`/`read`/`write`/`lseek`。

## 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| K-1 | 权限夹具在 root 下失效（chmod 000 仍可读） | `r12`/`r14` 的 PERMISSION 用例绿得可疑 | 测试先 `geteuid()==0` 则跳过该条并打印 `skip`，门禁把 skip 计为不通过并显式提示 |
| K-2 | 长路径超过 `FSGO_PATH_MAX` | `read_file` 返回 `FS_ERR_IO` | 与 ENAMETOOLONG 一并归 `IO`（D-009），不新增码 |
| K-3 | `g7-asan` 看门狗误杀慢机器 | 20 秒内未出报告 | 超时即失败并打印最后 20 行输出，便于区分「慢」与「没抓到」 |

## 需求洞（本相发现，未自行改需求）

| # | 洞 | 证据 | 影响 | 去向 |
| --- | --- | --- | --- | --- |
| H-7 | R-11 判据 3「断言旧指针内容已变」不是稳定后条件：`free` 后旧指针内容可能原样保留，读取它本身是 UAF | 分配器行为不可保证；违反契约的读取在 ASan 下会 abort | 该判据无法二值判定 | 已裁 D-009 之外不新增；R-11 记「部分」，判据 3 以「旧指针不得读取 + 新错误覆盖」替代并在卡与状态表标注 |
| H-8 | R-14 判据 2 把 `ENOTDIR` 并入 `NOT_FOUND`，与 R-02 的 `FS_ERR_NOT_DIR` 冲突 | R-14 原文 vs R-02 10 码 | `NOT_DIR` 成死代码 | **已裁 D-009**（`ENOTDIR→NOT_DIR`） |

## 收口记录（完成时填写）

| 项 | 结果 |
| --- | --- |
| E-1 … E-8 | 见 `docs/reviews/fsguard-ph02-evidence.md` |
| R-04 | 待收口 |
| R-08 | 待收口 |
| R-11 | 部分（H-7：判据 3 不可稳定判定） |
| R-12 | 待收口 |
| R-14 | 待收口 |
| 泄漏 | 待 Linux 补跑（B-3），不记通过 |
