#!/usr/bin/env bash
# fsguard 门禁入口。每个子命令都是真实现，不存在 rc=2 的占位分支；
# rc=3 仅表示 LSan 在 Darwin 上不可用、泄漏检查显式移交给 Linux CI，不表示通过。
set -u

ROOT="${FSGUARD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 2
CASE="${1:-}"
shift || true
TMP="$(mktemp -d "${TMPDIR:-/tmp}/fsguard-check.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*"; exit 1; }
# 只报结果、不退出：all 模式要连续跑完每个子门禁。
pass() { echo "PASS: $*"; return 0; }

g0_decisions() {
  [ -f docs/decisions/README.md ] || fail "G0: missing docs/decisions/README.md"
  grep -q 'verdict_id: V-001' docs/reviews/fsguard-verdict.md || fail "G0: missing verdict_id: V-001"
  [ -f docs/decisions/D-001.md ] || fail "G0: missing docs/decisions/D-001.md"
  [ -f docs/decisions/D-002.md ] || fail "G0: missing docs/decisions/D-002.md"
  [ -f docs/decisions/D-003.md ] || fail "G0: missing docs/decisions/D-003.md"
  [ -f docs/decisions/D-004.md ] || fail "G0: missing docs/decisions/D-004.md"
  [ -f docs/decisions/D-005.md ] || fail "G0: missing docs/decisions/D-005.md"
  for f in docs/decisions/D-001.md docs/decisions/D-002.md docs/decisions/D-003.md docs/decisions/D-004.md docs/decisions/D-005.md docs/decisions/D-006.md docs/decisions/D-007.md docs/decisions/D-008.md docs/decisions/D-009.md docs/decisions/D-010.md docs/decisions/D-011.md; do
    [ -f "$f" ] || fail "G0: missing $f"
    for field in id date anchor status trigger verdict judge seats scope criteria rationale invalidation affected; do
      grep -q "^${field}:" "$f" || fail "G0: $f missing field: $field"
    done
  done
  # D-011：fsguard 不把 std 变成硬依赖，且仍是单包单命名空间。
  if grep -v '^#' ct.pkg | grep -q '^dep = std'; then
    fail "G0: D-011 forbids a hard std dependency in ct.pkg"
  fi
  [ "z$(find src -mindepth 1 -maxdepth 1 -type d | sort | tr '\n' ' ')" = "zsrc/fsguard " ] \
    || fail "G0: D-011 keeps one namespace dir under src (got: $(find src -mindepth 1 -maxdepth 1 -type d | tr '\n' ' '))"
  grep -q '^## 3 符号级对照表' docs/reviews/fsguard-std-overlap.md \
    || fail "G0: D-011 evidence missing symbol table section"
  grep -q '^## 5 语义冲突' docs/reviews/fsguard-std-overlap.md \
    || fail "G0: D-011 evidence missing semantics section"
  grep -q '与 `ct-pkg/std` 的分工' README.md \
    || fail "G0: README missing the std division-of-labor section (D-011)"
  grep -q '与 std 的语义差异' docs/acceptance/fsguard-commands.md \
    || fail "G0: acceptance commands missing the std semantics addendum (D-011)"
  pass "g0-decisions: V-001 + D-001…D-011 have all 13 fields; no std dep; single namespace; std differences documented"
}

g1_command() {
  f=docs/acceptance/fsguard-commands.md
  [ -f "$f" ] || fail "G1: missing $f"
  if grep -q 'TODO\|TBD' "$f"; then
    fail "G1: $f contains TODO/TBD"
  fi
  count="$(grep -c '^## R-[0-9][0-9] ' "$f" || true)"
  [ "$count" -eq 17 ] || fail "G1: expected 17 R sections, got $count"
  n=1
  while [ "$n" -le 17 ]; do
    id="$(printf '%02d' "$n")"
    section="$(awk -v id="R-$id" '
      index($0, "## " id " ") == 1 { flag=1; next }
      flag && /^## R-/ { flag=0 }
      flag { print }
    ' "$f")"
    [ -n "$section" ] || fail "G1:R-$id missing section"
    printf '%s\n' "$section" | grep -q '^\$ ' || fail "G1:R-$id missing command line starting with \$ "
    printf '%s\n' "$section" | grep -q 'rc=' || fail "G1:R-$id missing rc= expectation"
    n=$((n + 1))
  done
  pass "g1-command: 17/17 R sections have command + rc="
}

g1_phase_card() {
  sel="${1:-all}"
  case "$sel" in
    all) list="PH-01 PH-02 PH-03" ;;
    PH-01|PH-02|PH-03) list="$sel" ;;
    *) echo "usage: $0 g1-phase-card {PH-01|PH-02|PH-03|all}"; exit 2 ;;
  esac
  for ph in $list; do
    f="docs/phases/$ph/card.md"
    vm="${ph#PH-0}"
    [ -f "$f" ] || fail "G1: missing $f"
    grep -q "^id: $ph\$" "$f" || fail "G1: $f missing field: id: $ph"
    grep -q "^version-minor: $vm\$" "$f" || fail "G1: $f missing field: version-minor: $vm"
    grep -q '^spec-version: 1\.10\.0$' "$f" || fail "G1: $f missing field: spec-version: 1.9.0"
    for sec in 目标 范围 交付物清单 任务清单 退出判据 依赖 已知风险; do
      grep -q "^## $sec\$" "$f" || fail "G1: $f missing section: $sec"
    done
    grep -q '任务清单每项可独立验收（6.6 T-6）' "$f" \
      || fail "G1: $f exit-criteria missing the 6.6 T-6 clause"
    n="$(grep -c '^| T-[0-9][0-9] |' "$f" || true)"
    [ "$n" -ge 1 ] || fail "G1: $f task list is empty"
    bad="$(awk -F'|' '/^\| T-[0-9][0-9] \|/ {
        gsub(/^ +| +$/, "", $4);
        gsub(/^ +| +$/, "", $5);
        if (NF != 7) print "columns:" $2;
        if ($4 !~ /(tools\/check\.sh|ct build)/) print "verify:" $2;
        if ($5 != "S" && $5 != "M") print "effort:" $2;
      }' "$f")"
    [ -z "$bad" ] || fail "G1: $f task rows incomplete: $bad"
    echo "ok $ph: 8 sections, $n tasks"
  done
  pass "g1-phase-card: $list cards complete"
}

g3_ph01() {
  CT="${CT:-$HOME/.local/bin/ct}"
  [ -x "$CT" ] || fail "G3: ct not found at $CT (set CT=/path/to/ct)"
  sel="${1:-all}"
  case "$sel" in
    r02) tests="r02_errors" ;;
    r05) tests="r05_normalize" ;;
    r06) tests="r06_is_under" ;;
    r09) tests="r09_check" ;;
    all) tests="r02_errors r05_normalize r06_is_under r09_check" ;;
    *) echo "usage: $0 g3-ph01 {r02|r05|r06|r09|all}"; exit 2 ;;
  esac
  if [ "$sel" = all ] || [ "$sel" = r02 ]; then
    if grep -rq '#define FS_ERR_' src/fsguard 2>/dev/null; then
      fail "G3:R-02 #define FS_ERR_ found in src/fsguard"
    fi
  fi
  for name in $tests; do
    src="test/fsguard/$name.ct"
    [ -f "$src" ] || fail "G3: missing $src"
    "$CT" build "$src" -I src --cflags "-Isrc" -o "$TMP/$name" >"$TMP/$name.build" 2>&1
    if [ $? -ne 0 ]; then
      cat "$TMP/$name.build"
      fail "G3: build $name failed"
    fi
    "$TMP/$name" >"$TMP/$name.out" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      cat "$TMP/$name.out"
      fail "G3: $name rc=$rc"
    fi
    if grep -q '^not ok' "$TMP/$name.out"; then
      cat "$TMP/$name.out"
      fail "G3: $name reported not ok"
    fi
    grep -q 'all checks passed' "$TMP/$name.out" \
      || { cat "$TMP/$name.out"; fail "G3: $name missing summary line"; }
    echo "ok $name: $(grep -c '^ok ' "$TMP/$name.out") checks"
  done
  pass "g3-ph01: $sel green"
}

g3_ph02() {
  CT="${CT:-$HOME/.local/bin/ct}"
  [ -x "$CT" ] || fail "G3: ct not found at $CT (set CT=/path/to/ct)"
  sel="${1:-all}"
  case "$sel" in
    r04) tests="r04_read_chunk" ;;
    r08) tests="r08_lifecycle" ;;
    r11) tests="r11_error" ;;
    r12) tests="r12_rw" ;;
    r14) tests="r14_errno" ;;
    all) tests="r04_read_chunk r08_lifecycle r11_error r12_rw r14_errno" ;;
    *) echo "usage: $0 g3-ph02 {r04|r08|r11|r12|r14|all}"; exit 2 ;;
  esac
  if [ "$sel" = all ] || [ "$sel" = r14 ]; then
    n="$(grep -c 'static int fsguard_errno_to_code' src/fsguard/FsGuard.h.ct || true)"
    [ "$n" -eq 1 ] || fail "G3:R-14 expected exactly one fsguard_errno_to_code, got $n"
    n="$(grep -r 'case EACCES' src/fsguard | wc -l | tr -d ' ')"
    [ "$n" -eq 1 ] || fail "G3:R-14 errno branch outside the single mapping: $n"
  fi
  if [ "$sel" = all ] || [ "$sel" = r12 ]; then
    grep -q 'open(norm' src/fsguard/FsGuard.h.ct \
      || fail "G3:R-12 read/write must use open/errno, not std::fs -1 alone"
  fi
  for name in $tests; do
    src="test/fsguard/$name.ct"
    [ -f "$src" ] || fail "G3: missing $src"
    "$CT" build "$src" -I src --cflags "-Isrc" -o "$TMP/$name" >"$TMP/$name.build" 2>&1
    if [ $? -ne 0 ]; then
      cat "$TMP/$name.build"
      fail "G3: build $name failed"
    fi
    "$TMP/$name" >"$TMP/$name.out" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      cat "$TMP/$name.out"
      fail "G3: $name rc=$rc"
    fi
    if grep -q '^not ok' "$TMP/$name.out"; then
      cat "$TMP/$name.out"
      fail "G3: $name reported not ok"
    fi
    if grep -q '^skip' "$TMP/$name.out"; then
      cat "$TMP/$name.out"
      fail "G3: $name skipped a fixture (environment gap, not a pass)"
    fi
    grep -q 'all checks passed' "$TMP/$name.out" \
      || { cat "$TMP/$name.out"; fail "G3: $name missing summary line"; }
    echo "ok $name: $(grep -c '^ok ' "$TMP/$name.out") checks"
  done
  pass "g3-ph02: $sel green"
}

g3_ph03() {
  CT="${CT:-$HOME/.local/bin/ct}"
  [ -x "$CT" ] || fail "G3: ct not found at $CT (set CT=/path/to/ct)"
  sel="${1:-all}"
  case "$sel" in
    r07) tests="r07_walk" ;;
    r10) tests="r10_policy" ;;
    r13) tests="r13_guard_walk" ;;
    all) tests="r07_walk r10_policy r13_guard_walk" ;;
    *) echo "usage: $0 g3-ph03 {r07|r10|r13|all}"; exit 2 ;;
  esac
  if [ "$sel" = all ]; then
    n="$(grep -c 'static inline int fsgo_walk_node' src/fsguard/FsGuardOps.shim.h || true)"
    [ "$n" -eq 1 ] || fail "G3:R-13 expected exactly one walker, got $n"
    n="$(grep -c 'fsg_error_clear(self)' src/fsguard/FsGuard.h.ct || true)"
    [ "$n" -eq 6 ] || fail "G3:R-11 expected 5 public ops + clear_error to call the clearer, got $n"
    grep -q '下一次' README.md || fail "G3:R-11 README missing borrow-invalidation clause"
  fi
  for name in $tests; do
    src="test/fsguard/$name.ct"
    [ -f "$src" ] || fail "G3: missing $src"
    "$CT" build "$src" -I src --cflags "-Isrc" -o "$TMP/$name" >"$TMP/$name.build" 2>&1
    if [ $? -ne 0 ]; then
      cat "$TMP/$name.build"
      fail "G3: build $name failed"
    fi
    "$TMP/$name" >"$TMP/$name.out" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
      cat "$TMP/$name.out"
      fail "G3: $name rc=$rc"
    fi
    if grep -q '^not ok' "$TMP/$name.out"; then
      cat "$TMP/$name.out"
      fail "G3: $name reported not ok"
    fi
    if grep -q '^skip' "$TMP/$name.out"; then
      cat "$TMP/$name.out"
      fail "G3: $name skipped a fixture (environment gap, not a pass)"
    fi
    grep -q 'all checks passed' "$TMP/$name.out"       || { cat "$TMP/$name.out"; fail "G3: $name missing summary line"; }
    echo "ok $name: $(grep -c '^ok ' "$TMP/$name.out") checks"
  done
  pass "g3-ph03: $sel green"
}

g4_static() {
  f=docs/acceptance/fsguard-status.md
  [ -f "$f" ] || fail "G4: missing $f"
  for t in TOCTOU 硬链接 挂载 PATH_MAX 符号链接环; do
    grep -q "$t" "$f" || fail "G4: missing threat term $t"
  done
  grep -q 'FS_ERR_NOT_DIR' "$f" || fail "G4: missing NOT_DIR disposition"
  grep -q 'ELOOP' "$f" || fail "G4: missing ELOOP disposition"
  grep -q 'LSan' "$f" || fail "G4: missing LSan disposition"
  grep -q '| Q-2 | 已裁' "$f" || fail "G4: Q-2 not marked resolved"
  grep -q 'D-006' "$f" || fail "G4: missing D-006 (Q-2)"
  grep -q 'D-009' "$f" || fail "G4: missing D-009 (ENOTDIR)"
  grep -q '| Q-3 | 已裁' "$f" || fail "G4: Q-3 not marked resolved"
  grep -q '| Q-4 | 已裁' "$f" || fail "G4: Q-4 not marked resolved"
  grep -q '| Q-5 | 已裁' "$f" || fail "G4: Q-5 not marked resolved"
  grep -q '| Q-6 | 已裁' "$f" || fail "G4: Q-6 not marked resolved"
  grep -q '| Q-7 | 已裁' "$f" || fail "G4: Q-7 not marked resolved"
  pass "g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-2…Q-7 resolved, D-006/D-009 anchored"
}

g5_anchor() {
  f=docs/acceptance/fsguard-status.md
  [ -f "$f" ] || fail "G5: missing $f"
  grep -q 'R-05' "$f" || fail "G5: missing R-05"
  grep -q 'Q-3' "$f" || fail "G5: missing Q-3"
  grep -q 'D-003' "$f" || fail "G5: missing D-003"
  grep -q 'R-06' "$f" || fail "G5: missing R-06"
  grep -q 'Q-6' "$f" || fail "G5: missing Q-6"
  grep -q 'D-002' "$f" || fail "G5: missing D-002"
  grep -q 'R-07' "$f" || fail "G5: missing R-07"
  grep -q 'Q-4' "$f" || fail "G5: missing Q-4"
  grep -q 'D-004' "$f" || fail "G5: missing D-004"
  grep -q 'R-10' "$f" || fail "G5: missing R-10"
  grep -q 'Q-7' "$f" || fail "G5: missing Q-7"
  grep -q 'D-005' "$f" || fail "G5: missing D-005"
  grep -q 'R-12' "$f" || fail "G5: missing R-12"
  grep -q 'Q-2' "$f" || fail "G5: missing Q-2"
  grep -q 'D-006' "$f" || fail "G5: missing D-006"
  grep -q 'R-14' "$f" || fail "G5: missing R-14"
  grep -q 'D-009' "$f" || fail "G5: missing D-009"
  lines="$(wc -l < docs/reviews/fsguard-verdict.md | tr -d ' ')"
  [ "$lines" -le 300 ] || fail "G5: verdict has $lines lines (>300)"
  pass "g5-anchor: R-05/06/07/10/12/14 + Q-2/3/4/6/7 + D-002/3/4/5/6/9; verdict $lines lines"
}

g6_contract() {
  c="$TMP/contract"
  mkdir -p "$c/docs/acceptance" "$c/docs/decisions" "$c/docs/reviews"
  cp docs/acceptance/fsguard-commands.md "$c/docs/acceptance/fsguard-commands.md"
  cp docs/decisions/README.md docs/decisions/D-001.md docs/decisions/D-002.md docs/decisions/D-003.md docs/decisions/D-004.md docs/decisions/D-005.md "$c/docs/decisions/"
  cp docs/reviews/fsguard-verdict.md "$c/docs/reviews/fsguard-verdict.md"
  awk '
    /^## R-09 / { inr=1; print; next }
    inr && /^## R-/ { inr=0 }
    inr && /^\$ / { next }
    { print }
  ' "$c/docs/acceptance/fsguard-commands.md" > "$c/docs/acceptance/broken.md"
  mv "$c/docs/acceptance/broken.md" "$c/docs/acceptance/fsguard-commands.md"
  out1="$(FSGUARD_ROOT="$c" "$ROOT/tools/check.sh" g1-command 2>&1)"
  rc1=$?
  [ "$rc1" -ne 0 ] || fail "G6: g1-command did not fail on broken copy"
  printf '%s\n' "$out1" | grep -q 'G1' || fail "G6: g1 failure missing G1 id"
  printf '%s\n' "$out1" | grep -q 'R-09' || fail "G6: g1 failure missing R-09"
  grep -v '^invalidation:' docs/decisions/D-002.md > "$c/docs/decisions/D-002.md"
  out2="$(FSGUARD_ROOT="$c" "$ROOT/tools/check.sh" g0-decisions 2>&1)"
  rc2=$?
  [ "$rc2" -ne 0 ] || fail "G6: g0-decisions did not fail on broken copy"
  printf '%s\n' "$out2" | grep -q 'G0' || fail "G6: g0 failure missing G0 id"
  printf '%s\n' "$out2" | grep -q 'D-002' || fail "G6: g0 failure missing D-002"
  grep -q 'G7:F1' "$ROOT/tools/check.sh" || fail "G6: g7 ASan failure lacks F1 id"
  grep -q 'G7:F2' "$ROOT/tools/check.sh" || fail "G6: g7 leak failure lacks F2 id"
  grep -q 'G4: missing' "$ROOT/tools/check.sh" || fail "G6: g4 failure lacks G4 id"
  grep -q 'G5: missing' "$ROOT/tools/check.sh" || fail "G6: g5 failure lacks G5 id"
  awk '/^pass\(\)/ { if ($0 ~ /exit/) bad = 1 } END { exit bad }' "$ROOT/tools/check.sh" \
    || fail "G6: pass() exits, all-mode truncates after the first gate"
  grep -q '( g7_leak )' "$ROOT/tools/check.sh" || fail "G6: all-mode must isolate g7_leak deferred rc=3"
  pass "g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present; all-mode continuous"
}

g7_asan() {
  cc="${CC:-cc}"
  "$cc" -fsanitize=address -g tools/fixtures/asan_clean.c -o "$TMP/asan_clean" \
    || fail "G7:F1 compile asan_clean.c failed"
  "$TMP/asan_clean" >"$TMP/asan_clean.out" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ]; then
    cat "$TMP/asan_clean.out"
    fail "G7:F1 asan_clean rc=$rc (expected 0)"
  fi
  "$cc" -fsanitize=address -g tools/fixtures/asan_uaf.c -o "$TMP/asan_uaf" \
    || fail "G7:F1 compile asan_uaf.c failed"
  # Darwin 上 ASan 报告后进程可能不退出（H-6）：用看门狗收口，不依赖外部 kill。
  "$TMP/asan_uaf" >"$TMP/asan_uaf.out" 2>&1 &
  pid=$!
  n=0
  while kill -0 "$pid" 2>/dev/null; do
    [ "$n" -ge 40 ] && break
    sleep 0.5
    n=$((n + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    echo "note: asan_uaf reported and did not exit; watchdog killed it after ${n} ticks"
  else
    wait "$pid" 2>/dev/null
    rc=$?
    if [ "$rc" -eq 0 ]; then
      cat "$TMP/asan_uaf.out"
      fail "G7:F1 asan_uaf rc=0 (AddressSanitizer did not catch the UAF)"
    fi
  fi
  if ! grep -q 'AddressSanitizer' "$TMP/asan_uaf.out"; then
    cat "$TMP/asan_uaf.out"
    fail "G7:F1 asan_uaf output missing AddressSanitizer"
  fi
  pass "g7-asan: clean rc=0; use-after-free caught"
}

g7_leak() {
  cc="${CC:-cc}"
  "$cc" -fsanitize=address -g tools/fixtures/leak.c -o "$TMP/leak" \
    || fail "G7:F2 compile leak.c failed"
  case "$(uname -s)" in
    Linux)
      "$cc" -fsanitize=address -g tools/fixtures/asan_clean.c -o "$TMP/asan_clean" \
        || fail "G7:F2 compile asan_clean.c failed"
      ASAN_OPTIONS=detect_leaks=1 "$TMP/asan_clean" >"$TMP/clean.out" 2>&1
      rc=$?
      if [ "$rc" -ne 0 ]; then
        cat "$TMP/clean.out"
        fail "G7:F2 LSan clean fixture rc=$rc (expected 0)"
      fi
      ASAN_OPTIONS=detect_leaks=1 "$TMP/leak" >"$TMP/leak.out" 2>&1
      rc=$?
      if [ "$rc" -eq 0 ]; then
        cat "$TMP/leak.out"
        fail "G7:F2 LSan did not report the leak (rc=0)"
      fi
      if ! grep -Eq 'LeakSanitizer|detected memory leaks' "$TMP/leak.out"; then
        cat "$TMP/leak.out"
        fail "G7:F2 leak output missing LeakSanitizer"
      fi
      pass "g7-leak: Linux ASan+LSan caught the leak"
      ;;
    Darwin)
      ASAN_OPTIONS=detect_leaks=0 "$TMP/leak" >"$TMP/leak.out" 2>&1
      rc=$?
      if [ "$rc" -ne 0 ]; then
        cat "$TMP/leak.out"
        fail "G7:F2 ASan with detect_leaks=0 failed rc=$rc"
      fi
      echo "DEFERRED: LSan is not supported on Darwin; leak gate delegated to Linux CI."
      echo "Linux command: ASAN_OPTIONS=detect_leaks=1 bash tools/check.sh g7-leak"
      exit 3
      ;;
    *)
      echo "DEFERRED: unsupported OS $(uname -s); LSan gate not run."
      exit 3
      ;;
  esac
}

case "$CASE" in
  g0-decisions) g0_decisions; exit 0 ;;
  g1-command) g1_command; exit 0 ;;
  g1-phase-card) g1_phase_card "$@"; exit 0 ;;
  g3-ph01) g3_ph01 "$@"; exit 0 ;;
  g3-ph02) g3_ph02 "$@"; exit 0 ;;
  g3-ph03) g3_ph03 "$@"; exit 0 ;;
  g4-static) g4_static; exit 0 ;;
  g5-anchor) g5_anchor; exit 0 ;;
  g6-contract) g6_contract; exit 0 ;;
  g7-asan) g7_asan; exit 0 ;;
  g7-leak) g7_leak ;;
  all)
    g0_decisions
    g1_command
    g1_phase_card
    g3_ph01
    g3_ph02
    g3_ph03
    g4_static
    g5_anchor
    g6_contract
    g7_asan
    # g7_leak 自己会 exit 3，放子 shell 里取值，避免 all 在第 11 个门禁处被截断。
    ( g7_leak ); leak_rc=$?
    if [ "$leak_rc" -eq 0 ]; then
      exit 0
    elif [ "$leak_rc" -eq 3 ]; then
      echo "note: 泄漏门禁 deferred（rc=3）；all 不以 0 收口"
      exit 3
    fi
    exit "$leak_rc"
    ;;
  *)
    echo "usage: $0 {g0-decisions|g1-command|g1-phase-card [PH-01|PH-02|all]|g3-ph01 [r02|r05|r06|r09]|g3-ph02 [r04|r08|r11|r12|r14]|g3-ph03 [r07|r10|r13]|g4-static|g5-anchor|g6-contract|g7-asan|g7-leak|all}"
    exit 2
    ;;
esac
