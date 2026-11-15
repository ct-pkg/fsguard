# PH-01 卡：路径词法与错误枚举

id: PH-01
status: in-progress
opened: 2026-11-15
spec-version: 1.9.0
version-minor: 1
roadmap: docs/planning/fsguard-roadmap.md

## 目标

把 `normalize_to`、`is_under`、`check` 与 `FsErrCode` 冻结成每条判据都能二值判定的词法核心；本相不解除任何读写与遍历能力。

## 范围

**做什么（R-02、R-05、R-06、R-09 的判定面）**

- `pub enum FsErrCode` 的 10 个成员与数值冻结（R-02）。
- `char *::normalize_to` 的九行表、容量边界、不访问文件系统（R-05）。
- `char *::is_under` 的路径段边界，与 `check` 共用同一实现（R-06）。
- `FsGuard` 的最小骨架与 `check` 判定顺序、错误码、`last_error` 写入（R-09）。

**不做什么**

- `read_file` / `write_file` / `read_chunk`（PH-02）、`walk`（PH-03）。
- 包形态终审、命名共存、平台分层、夹具门禁（PH-04）。
- Q-2 的裁定（本相不裁，时限见 B-3）。
- 不修改 `docs/requirements.md` 与 `docs/design.md` 正文。

## 交付物清单

| # | 路径 | 内容 |
| --- | --- | --- |
| 1 | `ct.pkg` | 包标识与版本（`version = 0.1.0`，对应 `version-minor: 1`） |
| 2 | `src/fsguard/FsGuard.h.ct` | `FsErrCode`、`FsError`、`FsGuard`、`fsguard_new`、`impl Drop` |
| 3 | `src/fsguard/FsGuardOps.m.ct` | `pub trait FsGuardOps` + `map trait … for type char *` |
| 4 | `src/fsguard/FsGuardOps.shim.h` | 规范化、段边界、重叠检测的 `static inline` 实现 |
| 5 | `test/fsguard/r02_errors.ct` | R-02 判据 1、2（裸名）与 3 的运行时断言 |
| 6 | `test/fsguard/r05_normalize.ct` | R-05 九行表 + 容量 + 重叠检测 |
| 7 | `test/fsguard/r06_is_under.ct` | R-06 判据 2–5 |
| 8 | `test/fsguard/r09_check.ct` | R-09 判据 1–7 |
| 9 | `tools/check.sh` | 新增 `g1-phase-card`、`g3-ph01` 子命令 |
| 10 | `docs/reviews/fsguard-ph01-evidence.md` | 门禁红绿原始输出与任务对照 |

## 任务清单

| ID | 交付物 | 验收命令 | effort | 回滚 |
| --- | --- | --- | --- | --- |
| T-01 | `ct.pkg` + `FsErrCode`（10 码冻结） | `bash tools/check.sh g3-ph01 r02` | S | `git revert <T-01 实现提交>` |
| T-02 | `normalize_to`（九行表、容量、重叠） | `bash tools/check.sh g3-ph01 r05` | M | `git revert <T-02 实现提交>` |
| T-03 | `is_under`（段边界，与 check 共用） | `bash tools/check.sh g3-ph01 r06` | S | `git revert <T-03 实现提交>` |
| T-04 | `FsGuard` 骨架 + `check` + `last_error` | `bash tools/check.sh g3-ph01 r09` | M | `git revert <T-04 实现提交>` |
| T-05 | 门禁 `g1-phase-card` 与 `g3-ph01` | `bash tools/check.sh g1-phase-card && bash tools/check.sh g3-ph01` | S | `git revert <T-05 实现提交>` |

每条任务的验收命令只验本任务的交付物，不借用「整个 phase 全绿」；一项任务不同时覆盖两条退出判据（6.6 T-5）。

## 退出判据

| # | 判据 | 命令 / 锚点 | 二值结果 |
| --- | --- | --- | --- |
| E-1 | R-02 本机可验部分：10 码名字与数值冻结；包内无 `#define FS_ERR_` | `bash tools/check.sh g3-ph01 r02` | rc=0 |
| E-2 | R-05 九行表逐行相等；容量不足返回 -1 且 `out[0]==0`；重叠输入返回 -1 | `bash tools/check.sh g3-ph01 r05` | rc=0 |
| E-3 | R-06 判据 2–5（判据 1 首例见 H-3，不计入本相退出） | `bash tools/check.sh g3-ph01 r06` | rc=0 |
| E-4 | R-09 判据 1–7（含 D-002 相对输入拒绝） | `bash tools/check.sh g3-ph01 r09` | rc=0 |
| E-5 | 本相全量：四条测试全部构建并运行通过 | `bash tools/check.sh g3-ph01` | rc=0 |
| E-6 | 任务清单每项可独立验收（6.6 T-6）：卡片字段齐全、每条任务有交付物/验收命令/effort/回滚 | `bash tools/check.sh g1-phase-card` | rc=0 |
| E-7 | 泄漏门禁：Darwin 上只记 `DEFERRED rc=3` 与待补跑命令，**不得记通过**；Linux 上 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` | `bash tools/check.sh g7-leak` | Darwin rc=3（deferred）；Linux rc=0 |
| E-8 | 契约门禁未被本相破坏：破损副本仍能红 | `bash tools/check.sh g6-contract` | rc=0 |

## 三条边界

**B-1 R-02 只是「部分可验收」。** 本相只冻结并验证：10 个成员、名字与数值、包内无 `#define`、裸名可用。剩余两项不在本相：

1. `FsErrCode::FS_ERR_*` 限定名取值在 ct 0.44.1 不可表达（`qualified type names are not supported`），R-02 判据 2 的后半句无法在本机验收 → 见 H-2。
2. `FS_ERR_NOT_DIR` 是否仍有调用路径，只能等 PH-02 的读写在 `open`/`stat` 上触发 `ENOTDIR` 才能验证 → 归 PH-02（R-12/R-14）。

因此 R-02 在 PH-01 收口时记「部分可验收」，不记通过。

**B-2 泄漏门禁在本机不可执行。** `g7-leak` 在 Darwin 只能输出

```console
DEFERRED: LSan is not supported on Darwin; leak gate delegated to Linux CI.
Linux command: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
```

并以 `rc=3` 退出。PH-01 收口时「无内存泄漏」只能记「待 Linux 补跑」，补跑命令即上面这条，不得写成通过。

另：本机 `g7-asan` 本次不可稳定执行——`asan_uaf` 被 ASan 捕获后进程不退出，门禁挂起，只能外部 `kill` 后才继续；`timeout 60` 复跑得到 `rc=124`（见 H-6）。因此 ASan 不列入本相退出判据，PH-02 收口前必须修门禁或改成带看门狗的版本。

**B-3 Q-2 必须在 PH-02 退出前裁掉。** Q-2（`write_file` 失败是否保留半截文件）是 R-12 的前置；PH-01 期间不裁，但时限写死在这里：**PH-02 收口前必须落 D-006**，不得拖到 PH-02 收口才发现。触发信号：PH-02 开卡时 Q-2 仍未裁，即为逾期。

## 依赖

- D-001（Q-5）、D-002（Q-6）、D-003（Q-3）已裁。
- roadmap 已批准，`docs/planning/fsguard-roadmap.md` §1 的 PH-01 行。
- ct 工具链：`~/.local/bin/ct`（v0.44.1）；`ct run` 不存在，见 H-1。
- 无外部服务、无网络依赖。

## 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| K-1 | `ct` 不在 PATH | `g3-ph01` 报 `ct not found` | 显式 `CT=~/.local/bin/ct`；门禁已做回退 |
| K-2 | 路径长度超过本相缓冲区 | `normalize_to` 返回 -1、`check` 返回 `FS_ERR_IO` | 记为 PH-02 `ELOOP`/`ENAMETOOLONG` 一并收口，不新增码 |
| K-3 | R-06 判据 1 与段边界定义冲突未裁 | `g3-ph01 r06` 中该行按 H-3 断言为 0 | 不自行改需求；报 H-3，等 D 记录 |
| K-4 | 重叠检测改变 R-05 判据 4 的原文口径 | 收口时 R-05 判据 4 与实现不一致 | 报 H-4，等 D 记录；本相取更严行为并留证 |

## 需求洞（本相发现，未自行改需求）

| # | 洞 | 证据 | 影响 | 建议去向 |
| --- | --- | --- | --- | --- |
| H-1 | `docs/acceptance/fsguard-commands.md` 用 `ct run`，但 ct 0.44.1 只有 `ct build` | `ct --help` 无 `run` 子命令 | 判据命令不可执行，与「门禁能真跑」冲突 | 改验收命令文档（非需求正文），本相已改 |
| H-2 | `FsErrCode::FS_ERR_*` 限定名不可表达 | ct 报 `qualified type names are not supported; use the bare name or an alias import` | R-02 判据 2 后半句本机无法验收 | R-02 保持「部分」；需 D 记录或改判据 |
| H-3 | R-06 判据 1 首例 `src/a.c` vs `/workspace/src` → 1，与「路径段边界」及 D-002 的绝对/相对口径冲突 | 段边界要求同种路径，相对路径不可能落在绝对前缀下 | R-06 判据 1 写不死 | 需 D 记录把示例改为绝对路径；本相按 0 实现并显式标注 |
| H-4 | R-05 判据 4 原文「实现不负责检测重叠」，与 roadmap PH-01 的 FSR-16「检测重叠并返回 -1」冲突 | `docs/requirements.md` R-05 判据 4 vs roadmap §3 | 同一行为两套口径 | 需 D 记录；本相实现检测并留证，不改需求正文 |
| H-5 | `FS_ERR_NOT_DIR` 在 PH-01 无调用路径 | `check` 是纯词法，不产生 `ENOTDIR` | R-02 无法在本相闭合该成员用途 | PH-02 映射 `ENOTDIR`；本相保留成员、不删 |
| H-6 | `g7-asan` 在 Darwin 会挂起：`asan_uaf` 打印报告后不退出 | `timeout 60 bash tools/check.sh g7-asan` → `rc=124`；不 kill 则进程常驻 | ASan 不能作为可重复门禁 | 门禁加看门狗或改用 `-fsanitize=address` 的退出型夹具；PH-02 收口前修 |

## 收口记录（完成时填写）

| 项 | 结果 |
| --- | --- |
| E-1 … E-8 | 待收口时逐条贴原始输出，见 `docs/reviews/fsguard-ph01-evidence.md` || R-02 | 部分可验收（B-1） |
| R-05 | 可验收（H-4 待裁，按更严行为实现） |
| R-06 | 判据 2–5 可验收；判据 1 首例待裁（H-3） |
| R-09 | 可验收 |
| 泄漏 | 待 Linux 补跑（B-2），不记通过 |
