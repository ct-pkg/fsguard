# PH-03 卡：遍历与策略

id: PH-03
status: in-progress
opened: 2026-11-15
spec-version: 1.10.0
version-minor: 3
roadmap: docs/planning/fsguard-roadmap.md

## 目标

把「列一层」变成「受策略约束的递归遍历」：一份共享 walker，`char *::walk` 与 `FsGuard::walk` 都走它；同时收掉 H-7，并给 R-02/R-17 的剩余部分定性。

## 范围

**做什么**

- R-07 `char *::walk(cb, ud, max_depth)`：集合相等、深度、中断、借用契约。
- R-10 策略配置：默认深度 16、覆盖语义、空串等价未配置、deny 方言。
- R-13 `FsGuard::walk`：逐项 check、deny 目录剪枝、不可读目录 fail-closed、共享 walker。
- H-7：R-11 判据 3 改为可核对条款（D-010）。
- R-02 / R-17 剩余部分定性。

**不做什么**

- 包形态终审、平台分层（PH-04）；不做并行遍历、不承诺顺序、不跟随符号链接。
- 不修改 `docs/requirements.md` 与 `docs/design.md` 正文。

## 交付物清单

| # | 路径 | 内容 |
| --- | --- | --- |
| 1 | `docs/decisions/D-010.md` | H-7 裁定 |
| 2 | `src/fsguard/FsGuardOps.shim.h` | 唯一递归 walker（`fsgo_walk` / `fsgo_walk_node`）与 `char *::walk` |
| 3 | `src/fsguard/FsGuard.h.ct` | `FsWalkCb`、`FsGuard::walk`、策略 setter 收敛 |
| 4 | `src/fsguard/FsGuardOps.m.ct` | `walk` 的 `map trait` |
| 5 | `test/fsguard/r07_walk.ct` | R-07 判据 1–6 |
| 6 | `test/fsguard/r10_policy.ct` | R-10 判据 1–5 |
| 7 | `test/fsguard/r13_guard_walk.ct` | R-13 判据 1–5 |
| 8 | `tools/check.sh` | `g3-ph03`、`g0` 收 D-010、R-11 可核对项 |
| 9 | `docs/reviews/fsguard-ph03-evidence.md` | 红绿原始输出 |

## 任务清单

| ID | 交付物 | 验收命令 | effort | 回滚 |
| --- | --- | --- | --- | --- |
| T-01 | D-010 与 R-02/R-17 定性 | `bash tools/check.sh g0-decisions` | S | `git revert <T-01 实现提交>` |
| T-02 | 共享 walker + `char *::walk` | `bash tools/check.sh g3-ph03 r07` | M | `git revert <T-02 实现提交>` |
| T-03 | 策略 setter 与默认深度 | `bash tools/check.sh g3-ph03 r10` | S | `git revert <T-03 实现提交>` |
| T-04 | `FsGuard::walk`（剪枝 + fail-closed） | `bash tools/check.sh g3-ph03 r13` | M | `git revert <T-04 实现提交>` |
| T-05 | `g3-ph03` 接入与全量绿 | `bash tools/check.sh g3-ph03` | S | `git revert <T-05 实现提交>` |

任务清单每项可独立验收（6.6 T-6）：每条任务的验收命令只验本任务交付物，不借「整相全绿」；一项任务不同时覆盖两条退出判据（6.6 T-5）。

## 退出判据

| # | 判据 | 命令 | 二值结果 |
| --- | --- | --- | --- |
| E-1 | H-7 已裁；R-02/R-17 剩余部分写明归属与缺项 | `bash tools/check.sh g0-decisions` | rc=0 |
| E-2 | R-07：集合相等、root 回调、深度 0/1、中断、20 层、借用 | `bash tools/check.sh g3-ph03 r07` | rc=0 |
| E-3 | R-10：默认 16、覆盖、空串、deny 方言与剪枝 | `bash tools/check.sh g3-ph03 r10` | rc=0 |
| E-4 | R-13：deny 剪枝、root 越界 0 回调、不可读 fail-closed、同一 walker | `bash tools/check.sh g3-ph03 r13` | rc=0 |
| E-5 | 本相全量 | `bash tools/check.sh g3-ph03` | rc=0 |
| E-6 | R-11 可核对项：文档失效条款 + 每个公开操作开头清错 | `bash tools/check.sh g3-ph02 r11` 且 `grep -c 'fsg_error_clear(self)' == 6`（5 个公开操作 + `clear_error` 自身） | rc=0 |
| E-7 | 泄漏门禁：仍只记 `DEFERRED rc=3` 与 Linux 补跑命令 | `bash tools/check.sh g7-leak` | Darwin rc=3 |

## 三条边界

**B-1 H-7 已裁，R-11 转可验收。** D-010 把判据 3 改成「文档写明失效 + 每个公开操作开头清错 + 新错误覆盖」三条可核对/可运行项；不再声称能运行证明旧指针失效。

**B-2 R-02 剩余部分本相收不掉。** 缺的是 `FsErrCode::FS_ERR_*` 限定名：ct 0.44.1 明确报 `qualified type names are not supported`。这是语言能力缺口，不是实现缺口；归属 **PH-04**，触发条件是 ct 升级后复跑 `test/fsguard/r02_errors.ct` 的限定名用例。本相记「部分」，不记通过。

**B-3 R-17 剩余部分本相收不掉。** 判据 1–4 可在本机执行（运行时夹具、门禁覆盖、集合排序、ASan）；判据 5 的 LSan 在 Darwin 不可执行，归属 **PH-04 / Linux CI**，缺的是 `ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak` 的一次绿。本相记「部分」，不记通过。

**B-4 泄漏台账不变。** 任何「无泄漏」结论只记「待 Linux 补跑」，不记通过。

## 依赖

- PH-01/PH-02 已收口；D-004（三参数 walk）、D-005（deny 方言）、D-010。
- POSIX `opendir`/`readdir`/`lstat`。

## 已知风险

| # | 风险 | 触发信号 | 处置 |
| --- | --- | --- | --- |
| K-1 | `max_depth` 过大导致栈溢出 | 深度 > 64 的输入 | 实现把递归上限钳在 64，超过返回 -1；判据只用到 16，不改需求口径 |
| K-2 | 权限夹具在 root 下失效 | `r13` 的不可读目录用例绿得可疑 | 用例先判 `geteuid()`；root 下打印 `skip`，门禁把 skip 计为不通过 |
| K-3 | 回调持有 entry 跨回调 | 借用断言失败 | walker 每层复用同一缓冲区；README 五条契约同步 |

## 需求洞（本相发现，未自行改需求）

| # | 洞 | 证据 | 影响 | 去向 |
| --- | --- | --- | --- | --- |
| H-9 | R-07 判据 6「下一次回调断言 entry 内容已变」不可观察：walker 按层复用缓冲区，同层相邻条目的 `saved` 指针就是新 entry 本身，`strcmp(saved, entry)` 永远相等 | `r07` 首版断言误判为「内容没变」 | 条款不能按原文运行 | 改为可观察证据：断言 entry 指针在回调间被复用（`saved == entry`），失效语义由 README 五条契约承载；措辞待 PH-04 复核 |

## 收口记录（完成时填写）

| 项 | 结果 |
| --- | --- |
| E-1 … E-7 | 见 `docs/reviews/fsguard-ph03-evidence.md` |
| 全量 `all` | 11 个门禁均实际执行；Darwin 上 rc=3（泄漏 deferred，不记通过）。顺带修掉 `all` 在 g0 后截断的假绿 |
| R-07 | 可验收（`r07` 17 checks；判据 6 按 H-9 以指针复用 + README 契约替代） |
| R-10 | 可验收（`r10` 13 checks） |
| R-13 | 可验收（`r13` 10 checks） |
| R-11 | 可验收（D-010；`r11` 16 checks + 清错计数 6） |
| 泄漏 | 待 Linux 补跑（B-4） |
