#!/usr/bin/env bash
set -euo pipefail
KID="${KID:-k1-provider}"
PUB="$(sed -n '2p' .well-known/minisign.pub)"
tools/policy/bootstrap_check.sh || true
tools/policy/run_v12.sh || true
KID="$KID" tools/policy/publish_policy.sh
for f in .well-known/policy/core.json .well-known/policy/bounds.json .well-known/policy/current.json .well-known/policy/changelog.json .well-known/policy/audit.merkle.json .well-known/policy/safety.switches.json .well-known/policy/history.index.json .well-known/policy/quorum.json; do
  minisign -Vm "$f" -P "$PUB" -x ".well-known/policy/sigs/$(basename "$f").$KID.minisig" >/dev/null
done
minisign -Vm dumps/sha256.json -P "$PUB" -x "dumps/sigs/sha256.json.$KID.minisig" >/dev/null || true
echo "DONE: run_all ok"
