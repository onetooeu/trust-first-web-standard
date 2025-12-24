#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY_DIR="${POLICY_DIR:-$BASE_DIR/.well-known/policy}"
SIGS_DIR="${SIGS_DIR:-$POLICY_DIR/sigs}"
PUB_PATH="${PUB_PATH:-$BASE_DIR/.well-known/minisign.pub}"

KID="${KID:-}"
QUIET="${QUIET:-1}"
REPORT="${REPORT:-$BASE_DIR/.well-known/policy/verification.report.json}"

log(){ [[ "$QUIET" = "1" ]] || echo "$*"; }

PUB="$(awk 'NF{gsub(/\r/,""); if($0 ~ /^RW[0-9A-Za-z+\/=]+$/){print; exit}}' "$PUB_PATH")"
[[ -n "${PUB:-}" ]] || { echo "NO_PUBKEY: $PUB_PATH" >&2; exit 24; }

sig_for() {
  local base="$1"
  if [[ -n "$KID" ]]; then
    echo "$SIGS_DIR/${base}.${KID}.minisig"
  else
    echo "$SIGS_DIR/${base}.minisig"
  fi
}

verify_one() {
  local json="$1"
  local sig="$2"
  [[ -f "$sig" ]] || { echo "MISSING_SIG: $sig" >&2; return 4; }
  minisign -Vm "$json" -P "$PUB" -x "$sig" >/dev/null 2>&1 || return 3
  return 0
}

ts_utc="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
files=("bounds.json" "current.json")
status="ok"
details=()

for f in "${files[@]}"; do
  json="$POLICY_DIR/$f"
  sig="$(sig_for "$f")"
  log "VERIFY: $f  sig=$(basename "$sig")"

  if [[ ! -f "$json" ]]; then
    status="fail"
    details+=("{\"file\":\"$f\",\"ok\":false,\"error\":\"MISSING_POLICY\"}")
    continue
  fi

  if verify_one "$json" "$sig"; then
    details+=("{\"file\":\"$f\",\"ok\":true}")
  else
    rc=$?
    status="fail"
    if [[ "$rc" = "4" ]]; then
      details+=("{\"file\":\"$f\",\"ok\":false,\"error\":\"MISSING_SIG\"}")
    else
      details+=("{\"file\":\"$f\",\"ok\":false,\"error\":\"BAD_SIG\"}")
    fi
  fi
done

{
  echo "{"
  echo "  \"ts_utc\": \"${ts_utc}\","
  echo "  \"kid\": \"${KID}\","
  echo "  \"status\": \"${status}\","
  echo "  \"checks\": ["
  printf "    %s\n" "$(IFS=,; echo "${details[*]}")"
  echo "  ]"
  echo "}"
} > "$REPORT" 2>/dev/null || true

[[ "$status" = "ok" ]] && { log "Verify-only: OK"; exit 0; }
echo "VERIFY_FAIL: see $REPORT" >&2
exit 3
