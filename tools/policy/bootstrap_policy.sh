#!/usr/bin/env bash
set -euo pipefail
mkdir -p .well-known/policy .well-known/policy/sigs dumps dumps/sigs
[ -f .well-known/policy/core.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.core.v1","policy_id":"onetoo.eu/trust-policy"}' > .well-known/policy/core.json
[ -f .well-known/policy/bounds.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.bounds.v1","limits":{"max_updates_per_day":4,"min_hours_between_updates":3}}' > .well-known/policy/bounds.json
[ -f .well-known/policy/current.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.current.v1","policy_version":"1.0.0+bootstrap","rules":[],"params":{},"meta":{"note":"bootstrap"}}' > .well-known/policy/current.json
[ -f .well-known/policy/changelog.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.changelog.v1","entries":[]}' > .well-known/policy/changelog.json
[ -f .well-known/policy/audit.merkle.json ] || printf '%s\n' '{"schema":"tfws-ap.audit.merkle.v1","events":[]}' > .well-known/policy/audit.merkle.json
[ -f .well-known/policy/safety.switches.json ] || printf '%s\n' '{"schema":"tfws-ap.safety.switches.v1","mode":"adaptive_enabled"}' > .well-known/policy/safety.switches.json
[ -f .well-known/policy/history.index.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.history.index.v1","entries":[],"head":{"policy_version":"1.0.0+bootstrap","status":"baseline"}}' > .well-known/policy/history.index.json
[ -f dumps/sha256.json ] || echo '{}' > dumps/sha256.json
echo "OK: bootstrap_policy done"
