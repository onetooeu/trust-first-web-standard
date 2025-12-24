# TFWS Workflow Guardrail (must-follow)

After ANY change in `.well-known/policy/*.json`, always run this exact order:

1) LF-normalize (strip CRLF): `tr -d '\r'`
2) Recompute `policy.bundle.json` sha256 inventory for all artifacts
3) Sign (bundle + criticals): bundle, current, bounds (+ audit if changed)
4) Verify: signatures + bundle inventory integrity
5) Commit / publish

Rule: build → sign → verify (never verify before signing).
