# PH-02 门禁证据（红绿原始输出）

> baseline: `696e0ab`（测试与门禁、不含读写实现）  
> green: `21ba5e5`（读写实现提交）  
> 红证一律用 `git archive` 解出的基线或 `/tmp` 变体副本；工作树原件不改。

## 1 `g3-ph02` 红：基线没有读写能力

```console
$ git archive 696e0ab | tar -x -C /tmp/fsguard-red-ph02
$ cd /tmp/fsguard-red-ph02 && CT=~/.local/bin/ct bash tools/check.sh g3-ph02 r04
test/fsguard/r04_read_chunk.ct:64:1: error: no method 'read_chunk' for type 'char *'
FAIL: G3: build r04_read_chunk failed
```

## 2 `g3-ph02` 绿：实现提交

```console
$ git archive 21ba5e5 | tar -x -C /tmp/fsguard-green-ph02
$ cd /tmp/fsguard-green-ph02 && CT=~/.local/bin/ct bash tools/check.sh g3-ph02
ok r04_read_chunk: 8 checks
ok r08_lifecycle: 15 checks
ok r11_error: 16 checks
ok r12_rw: 16 checks
ok r14_errno: 6 checks
PASS: g3-ph02: all green
```

PH-01 无回归：

```console
$ bash tools/check.sh g3-ph01
ok r02_errors: 11 checks
ok r05_normalize: 13 checks
ok r06_is_under: 9 checks
ok r09_check: 27 checks
PASS: g3-ph01: all green
```

## 3 行为红：删掉 `read_file` 的容量检查

`/tmp/fsguard-red-ph02-r12` 副本把 `if (want + 1 > cap)` 改成 `if (0)`：

```console
not ok 4 cap == size fails with BUFFER_TOO_SMALL
not ok 5 failed read_file leaves the buffer untouched
2 of 16 checks failed
FAIL: G3: r12_rw rc=1
```

## 4 `g4-static` 红：Q-2 回到未裁

`/tmp/fsguard-red-ph02-g4` 副本把状态表 `| Q-2 | 已裁（D-006） |` 改回 `| Q-2 | 未裁 |`：

```console
FAIL: G4: Q-2 not marked resolved
rc=1
```

## 5 `g1-phase-card` 红：PH-02 缺 `version-minor`

```console
FAIL: G1: docs/phases/PH-02/card.md missing field: version-minor: 2
rc=1
```

## 6 `g7-asan`：看门狗收口 H-6

绿（本机 1.5 秒返回，不再挂起；若进程不退出由看门狗 kill 后继续断言输出）：

```console
$ time bash tools/check.sh g7-asan
PASS: g7-asan: clean rc=0; use-after-free caught
rc=0
```

红（副本删掉 `p[0] = 'x';`，UAF 不再触发）：

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-ph02-asan bash tools/check.sh g7-asan
FAIL: G7:F1 asan_uaf rc=0 (AddressSanitizer did not catch the UAF)
rc=1
```

## 7 其余门禁

```console
$ bash tools/check.sh g0-decisions
PASS: g0-decisions: V-001 + D-001…D-009 have all 13 fields
$ bash tools/check.sh g1-command
PASS: g1-command: 17/17 R sections have command + rc=
$ bash tools/check.sh g1-phase-card
ok PH-01: 8 sections, 5 tasks
ok PH-02: 8 sections, 7 tasks
PASS: g1-phase-card: PH-01 PH-02 cards complete
$ bash tools/check.sh g4-static
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-2…Q-7 resolved, D-006/D-009 anchored
$ bash tools/check.sh g5-anchor
PASS: g5-anchor: R-05/06/07/10/12/14 + Q-2/3/4/6/7 + D-002/3/4/5/6/9; verdict 131 lines
$ bash tools/check.sh g6-contract
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present
$ bash tools/check.sh g7-leak
DEFERRED: LSan is not supported on Darwin; leak gate delegated to Linux CI.
rc=3
```

`g7-leak` 的 `rc=3` 是 deferred，不记通过；PH-02 的「无内存泄漏」仍记「待 Linux 补跑」。

## 8 任务对照

| 任务 | 验收命令 | 结果 |
| --- | --- | --- |
| T-01 | `bash tools/check.sh g0-decisions` | 9 份 D 全 13 字段 |
| T-02 | `bash tools/check.sh g3-ph02 r04` | 8 checks 绿 |
| T-03 | `bash tools/check.sh g3-ph02 r12` | 16 checks 绿；变体可红 |
| T-04 | `bash tools/check.sh g3-ph02 r08` | 15 checks 绿 |
| T-05 | `bash tools/check.sh g3-ph02 r11` | 16 checks 绿 |
| T-06 | `bash tools/check.sh g7-asan` | 1.5s 内返回 rc=0；变体可红 |
| T-07 | `bash tools/check.sh g3-ph02` | 全量绿 |
