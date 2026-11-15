# PH-04 门禁证据（前半：可核的绿）

> 采集时间：2026-11-16；主机 `uname -srm` = `Darwin 27.2.0 arm64`（macOS 27.2）；`ct v0.58.0`（`~/.local/bin/ct`）。  
> 采集提交：`8daca1f`（工作区另有未提交的 `ct.pkg` 两行 `publisher`/`ns-root`，本轮未改、未纳入提交；下列命令均不依赖这两行）。  
> 本文只记录**实际执行**得到的退出码与原始输出；未执行的一律写「未执行」，不以推断代替。

## 1 T-01 六处文档口径：`g4-static`

```console
$ bash tools/check.sh g4-static
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-1…Q-7 resolved, D-006/D-009/D-012 anchored, 6 doc re-statements current
RC=0
```

覆盖 E-1：status 标题 `D-001…D-012 后`、无 `0.44.1`、roadmap `15 条可验收、2 条部分可验收`、PH-01/02/03 三卡 `status: closed`、FSR-05/06 `已收口`、overlap 无 `S-6` 行。

## 2 T-02 R-15 `a\b` 字面断言：`g3-ph04 r15`

```console
$ bash tools/check.sh g3-ph04 r15
ok r15_posix: 7 checks
PASS: g3-ph04: r15 green
RC=0
```

七条断言的逐行输出（同一次构建产物直跑）：

```console
$ ~/.local/bin/ct build test/fsguard/r15_posix.ct -I src --cflags "-Isrc" -o /tmp/r15_posix.ph04 && /tmp/r15_posix.ph04
ok 1 R-15: backslash stays a literal character, not converted to slash
ok 2 R-15: dot is not collapsed inside a backslash segment
ok 3 R-15: backslash segment survives normalization next to real slashes
ok 4 R-15: drive-letter-like input is kept literal (no Win32 parsing)
ok 5 R-15: backslash is not a segment boundary
ok 6 R-15: /a\b is not under /a (one segment)
ok 7 R-15: /a\b/c is under /a\b
all checks passed
RC=0
```

## 3 T-03 R-16 能力对照表 + 门禁 grep：`g3-ph04 all`

`all` 的静态断言（R-01 包形态、R-15 无 Win32、R-16 README 对照表与 trait 四名、R-03 挂起标注、FSR-04 手工清单）无单独输出行，随下面的 `PASS` 一并判定：

```console
$ bash tools/check.sh g3-ph04 all
ok r15_posix: 7 checks
ok r18_known_bypass: 3 checks
PASS: g3-ph04: all green
RC=0
```

## 4 T-04 FSR-02/03 `known_bypass` 负例：`g3-ph04 r18`

```console
$ bash tools/check.sh g3-ph04 r18
ok r18_known_bypass: 3 checks
PASS: g3-ph04: r18 green
RC=0
```

逐条输出（硬链接在本机 APFS 上可用，未触发 `skip:`）：

```console
$ ~/.local/bin/ct build test/fsguard/r18_known_bypass.ct -I src --cflags "-Isrc" -o /tmp/r18_known_bypass.ph04 && /tmp/r18_known_bypass.ph04
ok 1 known_bypass: lexical check passes for a path that will be swapped
ok 2 known_bypass: read follows the swapped symlink and reads outside content (TOCTOU not mitigated)
ok 3 known_bypass: hardlink in root reads the outside inode (not mitigated)
all checks passed
RC=0
```

## 5 T-05 FSR-04 手工清单：`g3-ph04 all`

判据在 §3 同一次 `all` 内：`docs/acceptance/fsguard-manual-checks.md` 存在且含 `FSR-04`、`weaker variant`、`mount --bind`、`hdiutil`、`userns`。rc=0。

## 6 T-06 卡面挂起项与全量：`all`

```console
$ bash tools/check.sh all
PASS: g0-decisions: V-001 + D-001…D-012 have all 13 fields; no std dep; single namespace; std differences documented; sandbox claim closed
PASS: g1-command: 17/17 R sections have command + rc=
ok PH-01: 8 sections, 5 tasks
ok PH-02: 8 sections, 7 tasks
ok PH-03: 8 sections, 5 tasks
ok PH-04: 8 sections, 6 tasks
PASS: g1-phase-card: PH-01 PH-02 PH-03 PH-04 cards complete
ok r02_errors: 11 checks
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
ok r15_posix: 7 checks
ok r18_known_bypass: 3 checks
PASS: g3-ph04: all green
PASS: g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-1…Q-7 resolved, D-006/D-009/D-012 anchored, 6 doc re-statements current
PASS: g5-anchor: R-05/06/07/10/12/14 + Q-1/2/3/4/6/7 + D-002/3/4/5/6/9/12; verdict 131 lines
PASS: g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present; all-mode continuous; lsan record enforced
tools/check.sh: line 429:  3936 Abort trap: 6           "$TMP/asan_uaf" > "$TMP/asan_uaf.out" 2>&1
PASS: g7-asan: clean rc=0; use-after-free caught
SKIP: LSan is not supported on Darwin (ASan here has no leak detection); no leak verdict from this host.
SKIP: on Linux run: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
SKIP: then record host + command + raw output in docs/reviews/fsguard-lsan-linux.md (checked by g7-lsan-record)
PASS: g7-leak: SKIP on Darwin (no LSan); Linux record required
NOTE: g7-leak SKIPped on Darwin; run 'bash tools/check.sh g7-lsan-record' — red until a Linux record lands.
ALL_RC=0
```

`Abort trap: 6` 是 UAF 夹具被 ASan 捕获后的预期崩溃；该行是 shell 的作业通知，不是门禁失败，紧随其后的 `PASS` 才是判定。

## 7 泄漏两门禁（单独执行）

```console
$ bash tools/check.sh g7-leak
SKIP: LSan is not supported on Darwin (ASan here has no leak detection); no leak verdict from this host.
SKIP: on Linux run: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak
SKIP: then record host + command + raw output in docs/reviews/fsguard-lsan-linux.md (checked by g7-lsan-record)
PASS: g7-leak: SKIP on Darwin (no LSan); Linux record required
RC=0
$ bash tools/check.sh g7-lsan-record
FAIL: G7:LSAN-RECORD missing docs/reviews/fsguard-lsan-linux.md
  fix: on Linux run 'ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak',
       then copy docs/reviews/fsguard-lsan-linux.md.tmpl and fill host + command + verbatim output
       (must contain 'PASS: g7-leak: Linux ASan+LSan caught the leak').
  A Darwin SKIP is not a record; do not commit placeholders.
RC=1
```

两条口径：`g7-leak` 的 `rc=0` 是 SKIP 的返回码，**不是泄漏结论**；`g7-lsan-record` 的 `rc=1` 是后半 R-17 的挂起信号，按要求保持红。

## 8 任务对照

| 任务 | 验收命令 | 实际结果 |
| --- | --- | --- |
| T-01 | `bash tools/check.sh g4-static` | rc=0，六处口径全命中 |
| T-02 | `bash tools/check.sh g3-ph04 r15` | rc=0，`r15_posix` 7 checks |
| T-03 | `bash tools/check.sh g3-ph04 all` | rc=0，README 对照表与 trait 四名核对通过 |
| T-04 | `bash tools/check.sh g3-ph04 r18` | rc=0，`r18_known_bypass` 3 checks；硬链接可用，无 SKIP |
| T-05 | `bash tools/check.sh g3-ph04 all` | rc=0，FSR-04 五个关键词命中 |
| T-06 | `bash tools/check.sh all` | `ALL_RC=0`；`g1-phase-card` 认 PH-04 为 8 节 6 任务 |

## 9 退出判据

| # | 结果 | 依据 |
| --- | --- | --- |
| E-1 | 通过 | §1 `g4-static` rc=0 |
| E-2 | 通过 | §2 `r15` rc=0，7 checks；`g3-ph04 all` 内 `win32` 计数为 0 |
| E-3 | 通过 | §3 `g3-ph04 all` rc=0 |
| E-4 | 通过 | §4 `r18` rc=0，3 checks |
| E-5 | 通过 | §5 `g3-ph04 all` rc=0 |
| E-6 | 通过 | §6 `ALL_RC=0`；`g7-leak` 在 Darwin SKIP（不记泄漏结论） |
| E-7 | 通过 | §3/§6：卡内含 `ns-root`、`Type::Member`、`一台 Linux`、`PH-04 不得收口`；`g3-ph04 all` rc=0 |
| E-8 | 成立（不收口） | 前半全绿但后半四项仍挂起；`docs/phases/PH-04/card.md` 保持 `status: in-progress` |
| E-9 | 成立 | §8 每项任务的验收命令独立，不借整相全绿 |

## 10 后半四项：仍挂起（无通过证据）

| 项 | 状态 | 阻塞点（可核对） |
| --- | --- | --- |
| R-01 判据 2/3 | 挂起 | `ct install` 只打印 `-I vendor/fsguard`，单元在 `src/fsguard/`，消费者实测 `cannot resolve import 'fsguard/FsGuard'`；等 `ns-root`/包机制能标准安装 |
| R-03 判据 1/2/3 | 挂起 | 需共享库机制支持两个 `map trait` 同名方法与 `FsGuardOps::walk(...)` 限定调用；期间 `g3-ph04 all` 只核对卡内标注 |
| R-02 限定名 | 挂起 | 当前 `ct v0.58.0` 未复跑该用例（本机未验证是否已支持 `Type::Member`）；卡内仍记「等 CT 支持」 |
| R-17 Linux LSan | 挂起 | 无 Linux 主机，`docs/reviews/fsguard-lsan-linux.md` 不存在；`g7-lsan-record` rc=1 |

R-02 一项本轮只复述卡面挂起条件，未做「是否已支持」的新判定；若需提前解锁，需单独跑 `test/fsguard/r02_errors.ct` 的限定名用例并更新判据。

## 11 版本链断裂：已立案，本轮不修

`ct.pkg:14` 为 `version = 0.1.0`，而 PH-02/03/04 卡的 `version-minor` 分别是 2/3/4；PH-02、PH-03 收口未移动版本，仓库无 CHANGELOG、无版本 tag、`AGENTS.md` 0.3 记「无偏离」。按 6.7 V-1/V-6 立案：`issues/FSG-01.md`（`status: open`）。本轮不 bump、不打 tag、不登记偏离。
