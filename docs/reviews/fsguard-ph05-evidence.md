# PH-05 证据：消费者、限定名、Linux LSan

> phase: PH-05（2026-11-17）
> 基线：`f1641a8`（PH-04 收口后、PH-05 实施前）
> 口径：每个任务先给红基线，再给绿输出；命令均可从仓库根重跑。

## 0 环境

| 项 | 值 |
| --- | --- |
| 主机 | Darwin 27.2.0 arm64 |
| `ct` | `v0.62.0`（`~/.local/bin/ct`） |
| Linux 取证 | Lima `vz` / Debian 12 / `Linux 6.1.0-54-cloud-arm64 aarch64` / gcc 12.2.0 |
| 基线提交 | `f1641a8`（`git rev-parse --short HEAD`，实施前） |

## 1 T-01 消费者夹具（R-01 判据 2/3）

**红基线**：`f1641a8` 没有 `test/consumer/consumer.ct`，`g3-ph05` 也不存在；接线后先跑出「缺少夹具」的红。

```console
$ bash tools/check.sh g3-ph05 consumer
FAIL: G3: missing test/consumer/consumer.ct
rc=1
```

**绿输出**：

```console
$ bash tools/check.sh g3-ph05 consumer
ok consumer: 16 checks
PASS: g3-ph05: consumer green
rc=0
```

**断言覆盖**：`normalize_to` 成功/短缓冲、`is_under` 段边界、`read_chunk` offset 读、`walk` 具名回调（root + 文件）、`FsGuard` 的 `check` / `last_error`。测试文件不含任何包内头 `#include`；门禁用 `grep` 拒绝 `#include "fsguard/` 形式的绕过。

## 2 T-02 限定名（R-02 判据 2）

**红基线**：基线文件的限定名断言数为 0。

```console
$ git show f1641a8:test/fsguard/r02_errors.ct | grep -c 'check(FsErrCode::'
0
```

**绿输出**：

```console
$ bash tools/check.sh g3-ph01 r02
ok r02_qualified: 11 qualified assertions
ok r02_errors: 22 checks
PASS: g3-ph01: r02 green
rc=0
```

**说明**：`ct v0.62.0` 已满足 D-013 的触发条件 `ct >= v0.59.0`；裸名与限定名逐项相等，另有 `bare and qualified names agree` 一条。判据原文未改。

## 3 T-03 Linux LSan（R-17 判据 5）

**红基线**：记录文件不存在。

```console
$ bash tools/check.sh g7-lsan-record
FAIL: G7:LSAN-RECORD missing docs/reviews/fsguard-lsan-linux.md
  fix: on Linux run 'ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak',
       then copy docs/reviews/fsguard-lsan-linux.md.tmpl and fill host + command + verbatim output
       (must contain 'PASS: g7-leak: Linux ASan+LSan caught the leak').
  A Darwin SKIP is not a record; do not commit placeholders.
rc=1
```

**Linux 实测**（guest 内，完整仓库快照）：

```console
$ uname -srm
Linux 6.1.0-54-cloud-arm64 aarch64
$ cc --version | head -1
cc (Debian 12.2.0-14+deb12u1) 12.2.0
$ cd /tmp/fsg-lsan-repo
$ ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
PASS: g7-leak: Linux ASan+LSan caught the leak
rc=0
```

**记录门禁转绿**：

```console
$ bash tools/check.sh g7-lsan-record
PASS: g7-lsan-record: Linux LSan record present with host, command and output
rc=0
```

记录文件：`docs/reviews/fsguard-lsan-linux.md`（含 host、date、命令、原始输出、环境与复现方式）。

## 4 T-04 收口与全量

**全量**（Darwin；`g7-leak` 为 SKIP，Linux 记录单独校验）：

```console
$ bash tools/check.sh all
PASS: g0-decisions: V-001 + D-001…D-016 have all 13 fields; D-011 superseded by D-014; declared std dep is locked; single namespace; std differences documented; sandbox claim closed
PASS: g1-command: 17/17 R sections have command + rc=
ok PH-01: 8 sections, 5 tasks
ok PH-02: 8 sections, 7 tasks
ok PH-03: 8 sections, 5 tasks
ok PH-04: 8 sections, 7 tasks
ok PH-05: 8 sections, 4 tasks
PASS: g1-phase-card: PH-01 PH-02 PH-03 PH-04 PH-05 cards complete
ok r02_qualified: 11 qualified assertions
ok r02_errors: 22 checks
ok r05_normalize: 13 checks
ok r06_is_under: 9 checks
ok r09_check: 27 checks
PASS: g3-ph01: all green
ok r04_read_chunk: 8 checks
ok r08_lifecycle: 15 checks
ok r11_error: 16 checks
ok r12_rw: 16 checks
ok r14_errno: 6 checks
PASS: g3-ph02: all green
ok r07_walk: 17 checks
ok r10_policy: 13 checks
ok r13_guard_walk: 10 checks
PASS: g3-ph03: all green
ok r03_ambiguous: unqualified walk() rejected as ambiguous
ok r03_coexist: 7 checks
ok r03_qualified: 2 checks
ok r15_posix: 7 checks
ok r18_known_bypass: 3 checks
PASS: g3-ph04: all green
ok consumer: 16 checks
PASS: g3-ph05: all green
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-1…Q-7 resolved, D-006/D-009/D-012 anchored, 6 doc re-statements current
PASS: g5-anchor: R-05/06/07/10/12/14 + Q-1/2/3/4/6/7 + D-002/3/4/5/6/9/12; verdict 131 lines
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; D-014 dead declaration red, dependency-free ct.pkg still green; G4/G5/G7 ids present; all-mode continuous; lsan record enforced
PASS: g7-asan: clean rc=0; use-after-free caught
SKIP: LSan is not supported on Darwin (ASan here has no leak detection); no leak verdict from this host.
SKIP: on Linux run: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
SKIP: then record host + command + raw output in docs/reviews/fsguard-lsan-linux.md (checked by g7-lsan-record)
PASS: g7-leak: SKIP on Darwin (no LSan); Linux record required
NOTE: g7-leak SKIPped on Darwin; Linux record present, verify with 'bash tools/check.sh g7-lsan-record'.
rc=0
```

（`g7-asan` 的 UAF 夹具在 Darwin 由看门狗收口，stderr 的 `Abort trap` 是预期捕获，不是失败。）

## 5 退出判据对照

| # | 结果 | 证据 |
| --- | --- | --- |
| E-1 | 绿 | §1 `ok consumer: 16 checks` |
| E-2 | 绿 | §2 `11 qualified assertions` + 22 checks |
| E-3 | 绿 | §3 Linux `PASS` + `g7-lsan-record` rc=0 |
| E-4 | 绿 | §4 `all` rc=0 |
| E-5 | 绿 | `g1-phase-card PH-05` rc=0（4 tasks，字段齐全） |
| E-6 | 绿 | 收口提交：`ct.pkg` 0.5.0、CHANGELOG 0.5.0、annotated `v0.5.0` |
| E-7 | 绿 | `git diff --exit-code f1641a8 -- docs/requirements.md` 无输出（基线为 PH-05 实施前） |

## 6 未消解清单

PH-05 收口时按 6.7 清点：**1 条**（C-6，`deviation:` 的收敛方式与 V-1「不许多跳」）。本相未新增偏离，DEV-001 已收敛为偏移 0。
