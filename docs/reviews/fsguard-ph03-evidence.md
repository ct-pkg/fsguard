# PH-03 门禁证据（红绿原始输出）

> baseline: `14376a9`（三条遍历/策略测试与 `g3-ph03`，不含 walker 实现）  
> green: `87bf769`（walker、`FsGuard::walk`、夹具幂等修复后的提交树）  
> 红证一律用 `git archive` 解出的基线或 `/tmp` 变体副本；工作树原件不改。

## 1 `g3-ph03` 红：基线没有 `walk`

```console
$ git archive 14376a9 | tar -x -C /tmp/ph03_baseline
$ cd /tmp/ph03_baseline && ~/.local/bin/ct build test/fsguard/r07_walk.ct -I src --cflags "-Isrc" -o /tmp/ph03_baseline/r07
test/fsguard/r07_walk.ct:110:1: error: no method 'walk' for type 'char *'
```

## 2 `g3-ph03` 绿：实现提交

```console
$ bash tools/check.sh g3-ph03 all
ok r07_walk: 17 checks
ok r10_policy: 13 checks
ok r13_guard_walk: 10 checks
PASS: g3-ph03: all green
```

同一次 `all` 运行同时核对了静态条款：`fsgo_walk_node` 全仓唯一、`fsg_error_clear(self)` 出现 6 次（5 个公开操作 + `clear_error` 自身）、README 含「下一次」。

PH-01/PH-02 无回归：

```console
$ bash tools/check.sh g3-ph02 all
ok r04_read_chunk: 8 checks
ok r08_lifecycle: 15 checks
ok r11_error: 16 checks
ok r12_rw: 16 checks
ok r14_errno: 6 checks
PASS: g3-ph02: all green
$ bash tools/check.sh g3-ph01 all
ok r02_errors: 11 checks
ok r05_normalize: 13 checks
ok r06_is_under: 9 checks
ok r09_check: 27 checks
PASS: g3-ph01: all green
```

## 3 行为红：删掉 deny 目录剪枝

`/tmp/ph03_red` 副本删掉 walker 里的 `if (f == 2) return 0;`（filter 仍返回 2，但不再剪枝）：

```console
$ bash tools/check.sh g3-ph03 r13
ok 1 char *::walk sees all 7 entries
ok 2 deny pattern set
ok 3 guard walk completes when a subtree is denied
not ok 4 denied directory and its whole subtree produce 0 callbacks
ok 5 root is still visited
ok 6 sibling subtree is still visited
not ok 7 denied child is not visited
ok 8 out-of-bounds root returns OUT_OF_BOUNDS
ok 9 out-of-bounds root produces 0 callbacks
ok 10 unreadable directory fails closed with PERMISSION
2 of 10 checks failed
FAIL: G3: r13_guard_walk rc=1
```

## 4 条款红：删掉一次开头清错（D-010）

`/tmp/ph03_red2` 副本只删掉一个公开操作开头的 `fsg_error_clear(self);`：

```console
$ bash tools/check.sh g3-ph03 all
FAIL: G3:R-11 expected 5 public ops + clear_error to call the clearer, got 5
rc=1
```

## 5 `g7-asan`

```console
$ bash tools/check.sh g7-asan
PASS: g7-asan: clean rc=0; use-after-free caught
rc=0
```

## 6 其余门禁

```console
$ bash tools/check.sh g0-decisions
PASS: g0-decisions: V-001 + D-001…D-010 have all 13 fields
$ bash tools/check.sh g1-command
PASS: g1-command: 17/17 R sections have command + rc=
$ bash tools/check.sh g1-phase-card
ok PH-01: 8 sections, 5 tasks
ok PH-02: 8 sections, 7 tasks
ok PH-03: 8 sections, 5 tasks
PASS: g1-phase-card: PH-01 PH-02 PH-03 cards complete
$ bash tools/check.sh g4-static
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-2…Q-7 resolved, D-006/D-009 anchored
$ bash tools/check.sh g5-anchor
PASS: g5-anchor: R-05/06/07/10/12/14 + Q-2/3/4/6/7 + D-002/3/4/5/6/9; verdict 131 lines
$ bash tools/check.sh g6-contract
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present
$ bash tools/check.sh g7-leak
DEFERRED: LSan is not supported on Darwin; leak gate delegated to Linux CI.
Linux command: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
rc=3
```

`g7-leak` 的 `rc=3` 是 deferred，不记通过；PH-03 的「无内存泄漏」仍记「待 Linux 补跑」。

## 7 门禁修复：`all` 模式此前在 g0 后截断

收口扫描时发现 `bash tools/check.sh all` 只跑了 g0 就返回 0：`pass()` 里是 `exit 0`，第一个子门禁一结束就退出。这是**假绿**，本相一并修掉。

红（修复前，原文件）：

```console
$ bash tools/check.sh all
PASS: g0-decisions: V-001 + D-001…D-010 have all 13 fields
ALL_RC=0
```

绿（修复后：`pass()` 只返回；`g7_leak` 放子 shell 取值，Darwin 上 `all` 以 rc=3 收口而不是 0）：

```console
$ bash tools/check.sh all
PASS: g0-decisions: V-001 + D-001…D-010 have all 13 fields
PASS: g1-command: 17/17 R sections have command + rc=
ok PH-01: 8 sections, 5 tasks
ok PH-02: 8 sections, 7 tasks
ok PH-03: 8 sections, 5 tasks
PASS: g1-phase-card: PH-01 PH-02 PH-03 cards complete
ok r02_errors: 11 checks
...
ok r13_guard_walk: 10 checks
PASS: g3-ph03: all green
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-2…Q-7 resolved, D-006/D-009 anchored
PASS: g5-anchor: R-05/06/07/10/12/14 + Q-2/3/4/6/7 + D-002/3/4/5/6/9; verdict 131 lines
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present; all-mode continuous
PASS: g7-asan: clean rc=0; use-after-free caught
DEFERRED: LSan is not supported on Darwin; leak gate delegated to Linux CI.
Linux command: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
note: 泄漏门禁 deferred（rc=3）；all 不以 0 收口
ALL_RC=3
```

`g6-contract` 新增两条回归守卫：`pass()` 不得含 `exit`；`all` 必须用 `( g7_leak )` 隔离子 shell。红证（副本把 `pass()` 改回 `exit 0`）：

```console
$ bash tools/check.sh g6-contract
FAIL: G6: pass() exits, all-mode truncates after the first gate
rc=1
```

## 8 任务对照

| 任务 | 验收命令 | 结果 |
| --- | --- | --- |
| T-01 | `bash tools/check.sh g0-decisions` | 10 份 D 全 13 字段；D-010 关闭 H-7 |
| T-02 | `bash tools/check.sh g3-ph03 r07` | 17 checks 绿；基线无 `walk` 可红 |
| T-03 | `bash tools/check.sh g3-ph03 r10` | 13 checks 绿 |
| T-04 | `bash tools/check.sh g3-ph03 r13` | 10 checks 绿；去剪枝变体可红 |
| T-05 | `bash tools/check.sh g3-ph03` | 全量绿（含唯一 walker / 清错计数 / README 条款） |

## 9 退出判据

| # | 结果 | 备注 |
| --- | --- | --- |
| E-1 | rc=0 | H-7 由 D-010 关闭；R-02/R-17 归属 PH-04，见状态表 |
| E-2 | rc=0 | `r07` 17 checks；判据 6 按 H-9 以指针复用 + README 契约替代 |
| E-3 | rc=0 | `r10` 13 checks |
| E-4 | rc=0 | `r13` 10 checks |
| E-5 | rc=0 | `g3-ph03 all` |
| E-6 | rc=0 | `r11` 16 checks；清错计数 6；删一处即红 |
| E-7 | rc=3 | Darwin LSan 不可用，待 Linux 补跑，不记通过 |
