#!/usr/bin/env bash
set -euo pipefail

echo "== SIGN CEREMONY =="
echo "Trusted operator step. This may prompt for minisign password."
echo

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "WORKTREE_NOT_CLEAN: commit/stash changes before signing." >&2
    exit 30
  fi
fi

if [[ "${REQUIRE_KID:-0}" = "1" && -z "${KID:-}" ]]; then
  echo "REQUIRE_KID: set KID=... for production publishes" >&2
  exit 31
fi

KID="${KID:-k1-provider}" \
EVAL="${EVAL:-0}" \
PUBLISH="${PUBLISH:-1}" \
VERIFY="${VERIFY:-1}" \
QUIET="${QUIET:-0}" \
tools/policy/run_fast.sh

echo
echo "SIGN CEREMONY DONE"
