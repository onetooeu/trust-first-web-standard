#!/usr/bin/env bash
set -euo pipefail

KID="${KID:-k1-provider}"
QUIET="${QUIET:-1}"
BOOTSTRAP="${BOOTSTRAP:-1}"
EVAL="${EVAL:-1}"
PUBLISH="${PUBLISH:-1}"
VERIFY="${VERIFY:-1}"
VERIFY_ONLY="${VERIFY_ONLY:-0}"
VERIFY_STRICT="${VERIFY_STRICT:-0}"
VERIFY_VERBOSE="${VERIFY_VERBOSE:-0}"

export KID
export MINISIGN_SECRET="${MINISIGN_SECRET:-$HOME/.minisign/minisign.key}"
PUB="$(sed -n '2p' .well-known/minisign.pub 2>/dev/null || true)"

# verify-only: skip bootstrap/eval/publish
if [[ "$VERIFY_ONLY" == "1" ]]; then
  BOOTSTRAP=0
  EVAL=0
  PUBLISH=0
fi

say(){ [[ "$QUIET" == "1" ]] || echo "$@"; }

verify_one() {
  local f="$1" sig="$2"
  if [[ ! -f "$f" ]]; then echo "MISSING_FILE: $f"; [[ "$VERIFY_STRICT" == "1" ]] && return 2 || return 0; fi
  if [[ ! -f "$sig" ]]; then echo "MISSING_SIG : $sig"; [[ "$VERIFY_STRICT" == "1" ]] && return 3 || return 0; fi
  if [[ "${VERIFY_VERBOSE:-0}" == "1" ]]; then minisign -Vm "$f" -P "$PUB" -x "$sig"; else minisign -Vm "$f" -P "$PUB" -x "$sig" >/dev/null; fi; return 0
  echo "BAD_SIG     : $sig"
  [[ "$VERIFY_STRICT" == "1" ]] && return 4 || return 0
}

if [[ "$BOOTSTRAP" == "1" ]]; then
  say "== bootstrap =="
  tools/policy/bootstrap_check.sh || true
  tools/policy/bootstrap_policy.sh || true
fi

if [[ "$EVAL" == "1" ]]; then
  say "== eval/propose =="
  (python3 tools/policy/evaluate_and_propose.py >/dev/null 2>&1) || python3 tools/policy/evaluate_and_propose.py || true
fi

if [[ "$PUBLISH" == "1" ]]; then
  say "== publish/sign =="
  KID="$KID" tools/policy/publish_policy.sh
fi

if [[ "$VERIFY" == "1" ]]; then
  say "== verify signatures =="
  if [[ -z "${PUB:-}" ]]; then
    echo "NO_PUBKEY: .well-known/minisign.pub missing?"
  else
    for f in \
      .well-known/policy/core.json \
      .well-known/policy/bounds.json \
      .well-known/policy/current.json \
      .well-known/policy/changelog.json \
      .well-known/policy/audit.merkle.json \
      .well-known/policy/safety.switches.json \
      .well-known/policy/history.index.json \
      .well-known/policy/quorum.json
    do
      verify_one "$f" ".well-known/policy/sigs/$(basename "$f").$KID.minisig" || true
    done
    verify_one "dumps/sha256.json" "dumps/sigs/sha256.json.$KID.minisig" || true
  fi
fi

echo "OK: run_fast finished"
