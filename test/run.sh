#!/usr/bin/env bash
# test/run.sh — verify risk-scan.sh against fixtures.
# Exits non-zero on any failure.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/scripts/risk-scan.sh"

pass=0
fail=0

assert_equal() {
  local name="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" == "$expected" ]]; then
    echo "ok - $name"
    pass=$((pass + 1))
  else
    echo "FAIL - $name" >&2
    echo "  expected:" >&2
    echo "$expected" | sed 's/^/    /' >&2
    echo "  actual:" >&2
    echo "$actual" | sed 's/^/    /' >&2
    fail=$((fail + 1))
  fi
}

# Test 1: risky fixture should fire 5 flags.
expected_1="config-change — confirm per-env overrides exist
db-migration — check rollback and dual-write plan
security-sensitive — require second reviewer
infra-change — request SRE eyes
dependency-update — scan for new transitive CVEs"
actual_1="$(bash "$SCRIPT" "$HERE/fixtures/risky-files.txt")"
assert_equal "risky-files.txt emits 5 path-based flags" "$actual_1" "$expected_1"

# Test 2: clean fixture should emit nothing.
actual_2="$(bash "$SCRIPT" "$HERE/fixtures/clean-files.txt")"
assert_equal "clean-files.txt emits zero flags" "$actual_2" ""

# Test 3: body + stats inputs fire breaking-change + large-diff.
expected_3="breaking-change — check consumer compatibility
large-diff — suggest splitting before merging"
actual_3="$(bash "$SCRIPT" "$HERE/fixtures/clean-files.txt" \
  --body "$HERE/fixtures/breaking-body.txt" \
  --stats 400 200 25)"
assert_equal "body + stats inputs fire breaking-change + large-diff" "$actual_3" "$expected_3"

# Test 4: size-only triggers large-diff (files>20 boundary).
actual_4="$(bash "$SCRIPT" "$HERE/fixtures/clean-files.txt" --stats 0 0 21)"
assert_equal "changed_files > 20 triggers large-diff" "$actual_4" "large-diff — suggest splitting before merging"

# Test 5: size under thresholds is quiet.
actual_5="$(bash "$SCRIPT" "$HERE/fixtures/clean-files.txt" --stats 100 100 10)"
assert_equal "small diff is quiet" "$actual_5" ""

echo ""
echo "passed: $pass  failed: $fail"

if (( fail > 0 )); then
  exit 1
fi
