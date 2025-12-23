#!/usr/bin/env bash
set -euo pipefail
PY="${PY:-python3}"
BASE_DIR="${BASE_DIR:-.}"
POLICY_DIR="${POLICY_DIR:-$BASE_DIR/.well-known/policy}"
DATASET="${DATASET:-$BASE_DIR/tools/policy/training.dataset.json}"

"$PY" "$BASE_DIR/tools/policy/evaluate_and_propose.py" \
  --policy_current "$POLICY_DIR/current.json" \
  --bounds "$POLICY_DIR/bounds.json" \
  --model "$POLICY_DIR/scoring.model.json" \
  --dataset "$DATASET" \
  --out_metrics "$POLICY_DIR/metrics.snapshot.json" \
  --out_proposal "$POLICY_DIR/proposal.json" \
  --out_candidate_policy "$POLICY_DIR/candidate.policy.json"

echo "OK: wrote metrics.snapshot.json, proposal.json, candidate.policy.json"
