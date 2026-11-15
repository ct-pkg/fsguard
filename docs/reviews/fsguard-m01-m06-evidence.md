# M-01…M-06 红绿证据

> 环境：macOS，基线 `dfa2ffd`。红证全部在 `/tmp/fsguard-red-*` 副本上做，未提交。  
> 范围调整：M-04/M-05 原判据要求改 `requirements.md` 正文；本轮纪律禁止改正文，检查对象改为 `docs/acceptance/fsguard-status.md`（状态口径），判据意图不变。

## M-01 评审载体与编号

### 绿

```console
$ bash tools/check.sh g0-decisions
PASS: g0-decisions: V-001 + D-001/D-002 have all 13 fields
rc=0
```

### 红（副本删掉 D-002 的 `invalidation:` 字段）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-m01 bash tools/check.sh g0-decisions
FAIL: G0: docs/decisions/D-002.md missing field: invalidation
rc=1
```

## M-02 平台化泄漏门禁

### g7-asan 绿（macOS）

```console
$ bash tools/check.sh g7-asan
tools/check.sh: line 107:   253 Abort trap: 6           "$TMP/asan_uaf" > "$TMP/asan_uaf.out" 2>&1
PASS: g7-asan: clean rc=0; use-after-free caught
rc=0
```

UAF 用例按预期 abort，脚本捕获 `rc=134` 后确认输出含 `AddressSanitizer`，判绿；clean 用例 `rc=0`。

### g7-asan 红（副本把 clean 夹具换成非法 C）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-m02 bash tools/check.sh g7-asan
tools/fixtures/asan_clean.c:1:1: error: unknown type name 'this'
FAIL: G7:F1 compile asan_clean.c failed
rc=1
```

### g7-leak（macOS，显式 deferred，不是通过）

```console
$ bash tools/check.sh g7-leak
DEFERRED: LSan is not supported on Darwin; leak gate delegated to Linux CI.
Linux command: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
rc=3
```

Linux 补跑命令：`ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak`；期望 clean `rc=0`、leak 非 0 且输出含 `LeakSanitizer`。

## M-03 判据命令块与 g1-command

### 绿

```console
$ bash tools/check.sh g1-command
PASS: g1-command: 17/17 R sections have command + rc=
rc=0
```

### 红（副本删掉 R-09 的 `$ ` 命令行）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-m03 bash tools/check.sh g1-command
FAIL: G1:R-09 missing command line starting with $ 
rc=1
```

## M-04 静态一致性

### 绿

```console
$ bash tools/check.sh g4-static
PASS: g4-static: 5 threat terms, NOT_DIR, Q-3/4/7 unresolved, Q-5/6 resolved
rc=0
```

### 红（副本删掉 TOCTOU 行）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-m04 bash tools/check.sh g4-static
FAIL: G4: missing threat term TOCTOU
rc=1
```

## M-05 文档锚点

### 绿

```console
$ bash tools/check.sh g5-anchor
PASS: g5-anchor: R-06/Q-6/D-002 present; verdict 131 lines
rc=0
```

### 红（副本删掉 R-06 行）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-m05 bash tools/check.sh g5-anchor
FAIL: G5: missing R-06
rc=1
```

## M-06 门禁失败输出契约

### 绿（自测：在副本上制造 G0/D-002 与 G1/R-09 失败）

```console
$ bash tools/check.sh g6-contract
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present
rc=0
```

`g6-contract` 内部会复制命令块与 D 记录，分别删掉 R-09 命令和 D-002 的 `invalidation` 字段，再断言两个门禁失败输出分别带 `G1/R-09` 与 `G0/D-002`；它同时检查 `tools/check.sh` 中保留 `G7:F1/F2` 失败 id。

## 汇总

| 项 | 绿 | 红 | 备注 |
| --- | --- | --- | --- |
| M-01 | `g0-decisions` rc=0 | `G0` missing `invalidation` rc=1 | 13 字段全查 |
| M-02 | `g7-asan` rc=0 | `G7:F1` compile fail rc=1 | `g7-leak` macOS rc=3 deferred，不算通过 |
| M-03 | `g1-command` rc=0（17/17） | `G1:R-09` rc=1 | 命令块在实现后才执行 |
| M-04 | `g4-static` rc=0 | `G4` missing TOCTOU rc=1 | 检查状态文件，不改正文 |
| M-05 | `g5-anchor` rc=0 | `G5` missing R-06 rc=1 | verdict 131 行 ≤300 |
| M-06 | `g6-contract` rc=0 | 内置副本失败断言 | 失败输出带 G/R/D 编号 |
