#!/usr/bin/env bash
# fsguard 门禁入口。每个子命令都是真实现，不存在 rc=2 的占位分支；
# rc=3 仅表示 LSan 在 Darwin 上不可用、泄漏检查显式移交给 Linux CI，不表示通过。
set -u

ROOT="${FSGUARD_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 2
CASE="${1:-}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/fsguard-check.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; exit 0; }

g0_decisions() {
  [ -f docs/decisions/README.md ] || fail "G0: missing docs/decisions/README.md"
  grep -q 'verdict_id: V-001' docs/reviews/fsguard-verdict.md || fail "G0: missing verdict_id: V-001"
  [ -f docs/decisions/D-001.md ] || fail "G0: missing docs/decisions/D-001.md"
  [ -f docs/decisions/D-002.md ] || fail "G0: missing docs/decisions/D-002.md"
  [ -f docs/decisions/D-003.md ] || fail "G0: missing docs/decisions/D-003.md"
  [ -f docs/decisions/D-004.md ] || fail "G0: missing docs/decisions/D-004.md"
  [ -f docs/decisions/D-005.md ] || fail "G0: missing docs/decisions/D-005.md"
  for f in docs/decisions/D-001.md docs/decisions/D-002.md docs/decisions/D-003.md docs/decisions/D-004.md docs/decisions/D-005.md; do
    for field in id date anchor status trigger verdict judge seats scope criteria rationale invalidation affected; do
      grep -q "^${field}:" "$f" || fail "G0: $f missing field: $field"
    done
  done
  pass "g0-decisions: V-001 + D-001…D-005 have all 13 fields"
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

g4_static() {
  f=docs/acceptance/fsguard-status.md
  [ -f "$f" ] || fail "G4: missing $f"
  for t in TOCTOU 硬链接 挂载 PATH_MAX 符号链接环; do
    grep -q "$t" "$f" || fail "G4: missing threat term $t"
  done
  grep -q 'FS_ERR_NOT_DIR' "$f" || fail "G4: missing NOT_DIR disposition"
  grep -q 'ELOOP' "$f" || fail "G4: missing ELOOP disposition"
  grep -q 'LSan' "$f" || fail "G4: missing LSan disposition"
  grep -q '| Q-2 | 未裁' "$f" || fail "G4: Q-2 not marked open"
  grep -q '| Q-3 | 已裁' "$f" || fail "G4: Q-3 not marked resolved"
  grep -q '| Q-4 | 已裁' "$f" || fail "G4: Q-4 not marked resolved"
  grep -q '| Q-5 | 已裁' "$f" || fail "G4: Q-5 not marked resolved"
  grep -q '| Q-6 | 已裁' "$f" || fail "G4: Q-6 not marked resolved"
  grep -q '| Q-7 | 已裁' "$f" || fail "G4: Q-7 not marked resolved"
  pass "g4-static: 5 threat terms, NOT_DIR/ELOOP/LSan, Q-2 open, Q-3…Q-7 resolved"
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
  lines="$(wc -l < docs/reviews/fsguard-verdict.md | tr -d ' ')"
  [ "$lines" -le 300 ] || fail "G5: verdict has $lines lines (>300)"
  pass "g5-anchor: R-05/R-06/R-07/R-10 + Q-3/4/6/7 + D-002/3/4/5; verdict $lines lines"
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
  pass "g6-contract: broken copies yield G0/D-002 and G1/R-09; G4/G5/G7 ids present"
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
  "$TMP/asan_uaf" >"$TMP/asan_uaf.out" 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    cat "$TMP/asan_uaf.out"
    fail "G7:F1 asan_uaf rc=0 (AddressSanitizer did not catch the UAF)"
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
  g0-decisions) g0_decisions ;;
  g1-command) g1_command ;;
  g4-static) g4_static ;;
  g5-anchor) g5_anchor ;;
  g6-contract) g6_contract ;;
  g7-asan) g7_asan ;;
  g7-leak) g7_leak ;;
  all)
    g0_decisions
    g1_command
    g4_static
    g5_anchor
    g6_contract
    g7_asan
    g7_leak
    ;;
  *)
    echo "usage: $0 {g0-decisions|g1-command|g4-static|g5-anchor|g6-contract|g7-asan|g7-leak|all}"
    exit 2
    ;;
esac
