#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY_DIR="${POLICY_DIR:-$BASE_DIR/.well-known/policy}"
SIGS_DIR="${SIGS_DIR:-$POLICY_DIR/sigs}"
PUB_PATH="${PUB_PATH:-$BASE_DIR/.well-known/minisign.pub}"

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "MISSING_DEP: $1" >&2; exit 20; }; }

echo "== Preflight =="

need_cmd minisign
need_cmd awk
need_cmd sha256sum
need_cmd sed
need_cmd tr

if ! command -v jq >/dev/null 2>&1; then
  echo "WARN: jq not found (optional)"
fi

[[ -d "$POLICY_DIR" ]] || { echo "MISSING_DIR: $POLICY_DIR" >&2; exit 21; }
mkdir -p "$SIGS_DIR"

for f in bounds.json current.json; do
  [[ -f "$POLICY_DIR/$f" ]] || { echo "MISSING_POLICY: $POLICY_DIR/$f" >&2; exit 22; }
done

[[ -f "$PUB_PATH" ]] || { echo "NO_PUBKEY_FILE: $PUB_PATH" >&2; exit 23; }
PUB="$(awk 'NF{gsub(/\r/,""); if($0 ~ /^RW[0-9A-Za-z+\/=]+$/){print; exit}}' "$PUB_PATH")"
[[ -n "${PUB:-}" ]] || { echo "NO_PUBKEY: could not parse RW key from $PUB_PATH" >&2; exit 24; }

echo "OK: POLICY_DIR=$POLICY_DIR"
echo "OK: SIGS_DIR=$SIGS_DIR"
echo "OK: PUBKEY=present"
echo "Preflight: OK"
