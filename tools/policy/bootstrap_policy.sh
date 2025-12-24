#!/usr/bin/env bash
set -euo pipefail
mkdir -p .well-known/policy .well-known/policy/sigs dumps dumps/sigs
[ -f .well-known/policy/core.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.core.v1","policy_id":"onetoo.eu/trust-policy"}' > .well-known/policy/core.json
[ -f .well-known/policy/bounds.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.bounds.v1","limits":{"max_updates_per_day":4,"min_hours_between_updates":3}}' > .well-known/policy/bounds.json
[ -f .well-known/policy/current.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.current.v1","policy_version":"1.0.0+bootstrap","rules":[],"params":{"w_signature":1,"w_domain":1,"w_history":1,"w_revocation":1},"meta":{"note":"bootstrap"}}' > .well-known/policy/current.json
[ -f .well-known/policy/changelog.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.changelog.v1","entries":[]}' > .well-known/policy/changelog.json
[ -f .well-known/policy/audit.merkle.json ] || printf '%s\n' '{"schema":"tfws-ap.audit.merkle.v1","events":[]}' > .well-known/policy/audit.merkle.json
[ -f .well-known/policy/safety.switches.json ] || printf '%s\n' '{"schema":"tfws-ap.safety.switches.v1","mode":"adaptive_enabled"}' > .well-known/policy/safety.switches.json
[ -f .well-known/policy/history.index.json ] || printf '%s\n' '{"schema":"tfws-ap.policy.history.index.v1","entries":[],"head":{"policy_version":"1.0.0+bootstrap","status":"baseline"}}' > .well-known/policy/history.index.json
[ -f dumps/sha256.json ] || echo '{}' > dumps/sha256.json
echo "OK: bootstrap_policy done"


# ensure required params exist even if current.json already existed
tmp=".well-known/policy/current.json.tmp"
jq '.params = (.params // {})
    | .params.w_signature = (.params.w_signature // 1)
    | .params.w_domain = (.params.w_domain // 1)
    | .params.w_history = (.params.w_history // 1)
    | .params.w_revocation = (.params.w_revocation // 1)
    | .params.w_continuity_days = (.params.w_continuity_days // 0)
    | .params.threshold_allow = (.params.threshold_allow // 0)
  ' .well-known/policy/current.json > "$tmp" && [[ -f "$tmp" ]] && [[ -f "$tmp" ]] && mv "$tmp" .well-known/policy/current.json || true || true

# ensure bounds has safety defaults (needed by propose_step)
tmpb=".well-known/policy/bounds.json.tmp"
jq '.safety = (.safety // {}) | .safety.max_param_delta_per_update = (.safety.max_param_delta_per_update // 0.1)' \
  .well-known/policy/bounds.json > "$tmpb" && mv "$tmpb" .well-known/policy/bounds.json || true

# ensure bounds has params ranges (needed by propose_step)
tmpb=".well-known/policy/bounds.json.tmp"
jq '.params = (.params // {})
    | .params.w_signature = (.params.w_signature // {"min":0,"max":5})
    | .params.w_domain = (.params.w_domain // {"min":0,"max":5})
    | .params.w_history = (.params.w_history // {"min":0,"max":5})
    | .params.w_revocation = (.params.w_revocation // {"min":0,"max":5})
    | .params.w_continuity_days = (.params.w_continuity_days // {"min":0,"max":365})
  ' .well-known/policy/bounds.json > "$tmpb" && mv "$tmpb" .well-known/policy/bounds.json || true
# extend bounds param ranges for transparency knobs
tmpb2=".well-known/policy/bounds.json.tmp"
jq '.params = (.params // {})
    | .params.w_transparency_freshness = (.params.w_transparency_freshness // {"min":0,"max":5})
    | .params.w_transparency_proof = (.params.w_transparency_proof // {"min":0,"max":5})
    | .params.w_auditability = (.params.w_auditability // {"min":0,"max":5})
  ' .well-known/policy/bounds.json > "$tmpb2" && mv "$tmpb2" .well-known/policy/bounds.json || true
# ensure current has defaults for newer params
tmpc=".well-known/policy/current.json.tmp"
jq '.params = (.params // {})
    | .params.w_transparency_freshness = (.params.w_transparency_freshness // 0)
    | .params.w_transparency_proof = (.params.w_transparency_proof // 0)
    | .params.w_auditability = (.params.w_auditability // 0)
    | .params.threshold_allow = (.params.threshold_allow // 0)
    | .params.threshold_deny = (.params.threshold_deny // 0)
  ' .well-known/policy/current.json > "$tmpc" && mv "$tmpc" .well-known/policy/current.json || rm -f "$tmpc"

# ensure bounds_version exists
tmpbv=".well-known/policy/bounds.json.tmp"
jq '.bounds_version = (.bounds_version // "0.0.0+bootstrap")' \
  .well-known/policy/bounds.json > "$tmpbv" && mv "$tmpbv" .well-known/policy/bounds.json || rm -f "$tmpbv"

# ensure derived_from exists in current policy (bootstrap seed)
tmpdf=".well-known/policy/current.json.tmp"
jq '.derived_from = (.derived_from // {"core_version":"0.0.0+bootstrap","core_id":"core@bootstrap"})' \
  .well-known/policy/current.json > "$tmpdf" && mv "$tmpdf" .well-known/policy/current.json || rm -f "$tmpdf"
