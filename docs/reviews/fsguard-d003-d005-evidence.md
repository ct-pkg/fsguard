# D-003…D-005 裁定与门禁红绿证据

> 环境：macOS，基线 `74725e5`。红证在 `/tmp/fsguard-red-d003-*` 副本上做，未提交。  
> 本轮只动裁定/状态/门禁，不改 `requirements.md` / `design.md` 正文。

## g0-decisions（5 份 D 的 13 字段）

### 绿

```console
$ bash tools/check.sh g0-decisions
PASS: g0-decisions: V-001 + D-001…D-005 have all 13 fields
rc=0
```

### 红（副本删掉 D-004 的 `scope:` 字段）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-d003-g0 bash tools/check.sh g0-decisions
FAIL: G0: docs/decisions/D-004.md missing field: scope
rc=1
```

## g4-static（Q-2 未裁；Q-3…Q-7 已裁；威胁术语/NOT_DIR/ELOOP/LSan）

### 绿

```console
$ bash tools/check.sh g4-static
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-2 open, Q-3…Q-7 resolved
rc=0
```

### 红（副本把 Q-7 行改成未裁）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-d003-g4 bash tools/check.sh g4-static
FAIL: G4: Q-7 not marked resolved
rc=1
```

## g5-anchor（R-05/R-06/R-07/R-10 + Q-3/4/6/7 + D-002/3/4/5）

### 绿

```console
$ bash tools/check.sh g5-anchor
PASS: g5-anchor: R-05/R-06/R-07/R-10 + Q-3/4/6/7 + D-002/3/4/5; verdict 131 lines
rc=0
```

### 红（副本删掉 R-10 行）

```console
$ FSGUARD_ROOT=/tmp/fsguard-red-d003-g5 bash tools/check.sh g5-anchor
FAIL: G5: missing R-10
rc=1
```

## g6-contract（失败输出仍带 G0/G1/G4/G5/G7 编号）

```console
$ bash tools/check.sh g6-contract
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present
rc=0
```

## 汇总

| 门禁 | 绿 | 红 | 备注 |
| --- | --- | --- | --- |
| g0-decisions | rc=0，D-001…D-005 | `G0` 缺 `scope` rc=1 | 13 字段逐份检查 |
| g4-static | rc=0 | `G4` Q-7 未裁 rc=1 | 状态文件口径 |
| g5-anchor | rc=0 | `G5` 缺 R-10 rc=1 | verdict 131 行 |
| g6-contract | rc=0 | 内置副本失败断言 | 失败 id 仍成立 |
