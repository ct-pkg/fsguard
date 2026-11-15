# PH-01 门禁证据（红绿原始输出）

> baseline: `137804b`（`test(ph01)` 提交，含测试与门禁、不含 `src/fsguard`）  
> green: `b773b24`（`feat(ph01)` 实现提交）  
> 纪律：红证用 `git archive` 解出的基线目录与 `/tmp` 变体副本，不在工作树里改原件；下列输出均为原文。

## 1 `g1-phase-card`

绿（工作树，卡已定稿）：

```console
$ bash tools/check.sh g1-phase-card
PASS: g1-phase-card: PH-01 has 8 required sections, 5 tasks with verify+effort+rollback
rc=0
```

红（`/tmp/fsguard-red-ph01-card` 副本，删掉 `version-minor` 一行）：

```console
$ grep -v '^version-minor: 1$' card.md > tmp && mv tmp card.md
$ FSGUARD_ROOT=/tmp/fsguard-red-ph01-card bash tools/check.sh g1-phase-card
FAIL: G1: docs/phases/PH-01/card.md missing field: version-minor: 1
rc=1
```

## 2 `g3-ph01` 红：基线缺实现

从 `137804b` 解出干净树，不带 `src/fsguard`：

```console
$ git archive 137804b | tar -x -C /tmp/fsguard-baseline-ph01
$ cd /tmp/fsguard-baseline-ph01 && bash tools/check.sh g3-ph01 r02
ctc: cannot resolve import 'fsguard/FsGuard'
FAIL: G3: build r02_errors failed
rc=1
```

## 3 `g3-ph01` 绿：实现提交

从 `b773b24` 解出干净树执行：

```console
$ git archive b773b24 | tar -x -C /tmp/fsguard-green-ph01
$ cd /tmp/fsguard-green-ph01 && bash tools/check.sh g3-ph01
ok r02_errors: 11 checks
ok r05_normalize: 13 checks
ok r06_is_under: 9 checks
ok r09_check: 27 checks
PASS: g3-ph01: all green
rc=0
```

## 4 `g3-ph01` 行为红：改坏规范化

在 `/tmp/fsguard-red-ph01-g3` 副本上把「绝对路径根处钳住」改成「绝对路径也保留 `..`」，
其余不动：

```console
$ python3 - <<'PY'
s = open("src/fsguard/FsGuardOps.shim.h").read()
s = s.replace("} else if (!abs_path) {", "} else if (1) {")
open("src/fsguard/FsGuardOps.shim.h", "w").write(s)
PY
$ FSGUARD_ROOT=/tmp/fsguard-red-ph01-g3 bash tools/check.sh g3-ph01 r05
# /../etc -> /etc: rc=0 got [/../etc] want [/etc]
# /tmp/../../../etc -> /etc: rc=0 got [/../../etc] want [/etc]
not ok 7 /../etc -> /etc
not ok 8 /tmp/../../../etc -> /etc
2 of 13 checks failed
FAIL: G3: r05_normalize rc=1
rc=1
```

## 5 既有门禁未被破坏

```console
$ bash tools/check.sh g0-decisions
PASS: g0-decisions: V-001 + D-001…D-005 have all 13 fields
rc=0
$ bash tools/check.sh g1-command
PASS: g1-command: 17/17 R sections have command + rc=
rc=0
$ bash tools/check.sh g4-static
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-2 open, Q-3…Q-7 resolved
rc=0
$ bash tools/check.sh g5-anchor
PASS: g5-anchor: R-05/R-06/R-07/R-10 + Q-3/4/6/7 + D-002/3/4/5; verdict 131 lines
rc=0
$ bash tools/check.sh g6-contract
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present
rc=0
```

## 6 泄漏与 ASan

```console
$ bash tools/check.sh g7-leak
DEFERRED: LSan is not supported on Darwin; leak gate delegated to Linux CI.
Linux command: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
rc=3
```

`rc=3` 是 deferred，不是通过。PH-01 的「无内存泄漏」记「待 Linux 补跑」。

`g7-asan` 本机不可稳定执行，见卡 H-6：

```console
$ timeout 60 bash tools/check.sh g7-asan
tools/check.sh: line 191: 99034 Terminated: 15          "$TMP/asan_uaf" > "$TMP/asan_uaf.out" 2>&1
rc=124
```

被 ASan 捕获的 `asan_uaf` 打印报告后不退出，只能外部 `kill`；因此 ASan 不列入本相退出判据。

## 7 任务对照

| 任务 | 验收命令 | 结果 |
| --- | --- | --- |
| T-01 | `bash tools/check.sh g3-ph01 r02` | 11 checks 全绿 |
| T-02 | `bash tools/check.sh g3-ph01 r05` | 13 checks 全绿；变体副本可红 |
| T-03 | `bash tools/check.sh g3-ph01 r06` | 9 checks 全绿 |
| T-04 | `bash tools/check.sh g3-ph01 r09` | 27 checks 全绿 |
| T-05 | `bash tools/check.sh g1-phase-card && bash tools/check.sh g3-ph01` | 两条均 rc=0 |
