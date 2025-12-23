#!/usr/bin/env bash
set -euo pipefail
KID="${KID:-k1-provider}"

tools/policy/bootstrap_check.sh || true
tools/policy/bootstrap_policy.sh || true
tools/policy/run_v12.sh || true

KEY="./.secrets/minisign.key"
[ -f "$KEY" ] || KEY="$HOME/.minisign/minisign.key"

if [ -f "$KEY" ]; then
  echo "== publish (signing) =="
  MINISIGN_KEY="$KEY" KID="$KID" tools/policy/publish_policy.sh
else
  echo "== verify-only (no secret key found) =="
fi

PUB="$(sed -n '2p' .well-known/minisign.pub 2>/dev/null || true)"
[ -n "$PUB" ] || { echo "ERROR: missing .well-known/minisign.pub"; exit 1; }

for f in .well-known/policy/core.json .well-known/policy/bounds.json .well-known/policy/current.json .well-known/policy/changelog.json .well-known/policy/audit.merkle.json .well-known/policy/safety.switches.json .well-known/policy/history.index.json .well-known/policy/quorum.json; do
  sig=".well-known/policy/sigs/$(basename "$f").$KID.minisig"
  [ -f "$sig" ] && minisign -Vm "$f" -P "$PUB" -x "$sig" >/dev/null || true
done

sig2="dumps/sigs/sha256.json.$KID.minisig"
[ -f "$sig2" ] && minisign -Vm dumps/sha256.json -P "$PUB" -x "$sig2" >/dev/null || true
echo "DONE: run_all finished"
