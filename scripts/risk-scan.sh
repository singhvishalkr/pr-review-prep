#!/usr/bin/env bash
# risk-scan.sh — emit one line per heuristic risk flag for a PR's file list.
#
# Usage:
#   gh pr diff <PR_URL> --name-only > files.txt
#   bash scripts/risk-scan.sh files.txt [--body <PR_BODY_FILE>] [--stats <added> <removed> <files>]
#
# Output format: one flag per line.
#   config-change — confirm per-env overrides exist
#
# Exit 0 if no flags, 0 with flags on stdout if any. Non-zero only on bad input.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: risk-scan.sh <files.txt> [--body <pr_body_file>] [--stats <added> <removed> <files>]" >&2
  exit 2
fi

FILES="$1"
shift || true

BODY_FILE=""
ADDED=""
REMOVED=""
CHANGED_FILES=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --body)
      BODY_FILE="${2:-}"
      shift 2
      ;;
    --stats)
      ADDED="${2:-}"
      REMOVED="${3:-}"
      CHANGED_FILES="${4:-}"
      shift 4
      ;;
    *)
      echo "unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$FILES" ]]; then
  echo "files list not found: $FILES" >&2
  exit 2
fi

flag() {
  echo "$1"
}

# Path-based heuristics. grep -E over the file list, case-sensitive on purpose.
if grep -Eq '(^|/)application(-[a-zA-Z0-9]+)?\.ya?ml$|(^|/)\.env(\.[a-zA-Z0-9]+)?$' "$FILES"; then
  flag "config-change — confirm per-env overrides exist"
fi

if grep -Eq 'Migration\.java$|(^|/)migrations/|\.sql$' "$FILES"; then
  flag "db-migration — check rollback and dual-write plan"
fi

if grep -Eq '(^|/)(security|auth|authz|authn)/' "$FILES"; then
  flag "security-sensitive — require second reviewer"
fi

if grep -Eq '(^|/)Dockerfile$|\.tf$|(^|/)helm/|(^|/)k8s/|(^|/)kubernetes/' "$FILES"; then
  flag "infra-change — request SRE eyes"
fi

if grep -Eq '(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|go\.sum|Gemfile\.lock|poetry\.lock|Cargo\.lock)$' "$FILES"; then
  flag "dependency-update — scan for new transitive CVEs"
fi

# Body-based heuristic (optional input).
if [[ -n "$BODY_FILE" && -f "$BODY_FILE" ]]; then
  if grep -Eiq 'BREAKING[[:space:]-]?CHANGE' "$BODY_FILE"; then
    flag "breaking-change — check consumer compatibility"
  fi
fi

# Size heuristic (optional input). --stats are integers; accept missing gracefully.
if [[ -n "$ADDED" && -n "$REMOVED" && -n "$CHANGED_FILES" ]]; then
  # shellcheck disable=SC2004  # numeric comparison is clearer with literals
  total=$(( ADDED + REMOVED ))
  if (( CHANGED_FILES > 20 )) || (( total > 500 )); then
    flag "large-diff — suggest splitting before merging"
  fi
fi

exit 0
