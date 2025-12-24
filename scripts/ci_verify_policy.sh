#!/usr/bin/env bash
set -euo pipefail

# CI-friendly verification of TFWS-AP artifacts.
# Fails if quorum signatures are missing or invalid.

POLICY_DIR="${POLICY_DIR:-.well-known/policy}"

# Basic JSON sanity
jq -e . "$POLICY_DIR/core.json" >/dev/null
jq -e . "$POLICY_DIR/bounds.json" >/dev/null
jq -e . "$POLICY_DIR/current.json" >/dev/null

# Quorum signatures
TOOLS_DIR="${TOOLS_DIR:-tools/policy}"
"$TOOLS_DIR/verify_quorum.sh"

echo "OK: policy artifacts verified"
