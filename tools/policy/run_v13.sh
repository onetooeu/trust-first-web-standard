#!/usr/bin/env bash
set -euo pipefail
PY="${PY:-python3}"
BASE_DIR="${BASE_DIR:-.}"
POLICY_DIR="${POLICY_DIR:-$BASE_DIR/.well-known/policy}"

"$PY" "$BASE_DIR/tools/policy/runner_v13.py" --policy_dir "$POLICY_DIR" --do enforce

REG_OK="$(jq -r '.decision.regression_ok' "$POLICY_DIR/metrics.snapshot.json" 2>/dev/null || echo "true")"
MODE="$(jq -r '.mode' "$POLICY_DIR/safety.switches.json")"

if [[ "$REG_OK" == "false" ]]; then
  echo "Regression detected -> rollback plan"
  "$PY" "$BASE_DIR/tools/policy/runner_v13.py" --policy_dir "$POLICY_DIR" --do rollback_if_regression
  exit 0
fi

if [[ "$MODE" != "adaptive_enabled" ]]; then
  echo "Safety mode blocks publish: $MODE"
  exit 0
fi

echo "OK: proceed to apply_candidate_as_current then publish_policy.sh"
