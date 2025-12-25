# TFWS v1.x Closure Index

This folder contains the canonical closure evidence for TFWS v1.x.
Goal: enable a third-party verifier (human or agent) to reproduce trust checks from repository artifacts.

## Canonical snapshot
- Git tag: `v1x-closure` (closure snapshot; repository is frozen at this tag)

## Evidence files

### Agent trust verdict (text)
- File: `AGENT_TRUST_VERDICT_2025-12-25.txt`
- Proves:
  - minisign public key used as identity root
  - critical policy signatures verified (bundle/current/bounds)
  - bundle inventory integrity verified (sha256 for artifacts[])
  - per-artifact signature verification succeeded (sig_path minisigs)

### Agent trust verdict (machine-readable)
- File: `agent_verdict_2025-12-25.json`
- Proves:
  - same verdict as text, structured for automation/agents

### Local archive signature handling
- File: `ARCHIVE_SIGNATURE_NOTE_2025-12-25.txt`
- Proves:
  - why `archive/*.minisig` may be intentionally excluded from git
  - how to verify locally-held archive payload + signature

### Tag attestation (detached signature)
- File: `TAG_ATTESTATION_v1x-closure_2025-12-25.txt`
- Signature: `TAG_ATTESTATION_v1x-closure_2025-12-25.txt.minisig`
- Proves:
  - the closure tag `v1x-closure` points to a specific commit hash
  - verifier can validate using `.well-known/minisign.pub`

## Recommended verification commands (repro)

A) Extract public key:
- PUB="$(awk 'NF{gsub(/\r/,""); if($0 ~ /^RW[0-9A-Za-z+\/=]+$/){print; exit}}' .well-known/minisign.pub)"

B) Verify tag attestation:
- minisign -Vm docs/closure/TAG_ATTESTATION_v1x-closure_2025-12-25.txt -P "$PUB" -x docs/closure/TAG_ATTESTATION_v1x-closure_2025-12-25.txt.minisig

C) Verify critical policy signatures (example, k1-provider):
- minisign -Vm .well-known/policy/current.json -P "$PUB" -x .well-known/policy/sigs/current.json.k1-provider.minisig
- minisign -Vm .well-known/policy/bounds.json  -P "$PUB" -x .well-known/policy/sigs/bounds.json.k1-provider.minisig
- minisign -Vm .well-known/policy/policy.bundle.json -P "$PUB" -x .well-known/policy/sigs/policy.bundle.json.k1-provider.minisig

D) Verify bundle inventory integrity (sha256):
- compare `policy.bundle.json` artifacts[].sha256 vs local file hashes
- note: bundle self-hash entry is cyclic by design and may be skipped

E) Verify per-artifact signatures (Level 3):
- bash tools/agent_level3_verify.sh

## Notes
- `.gitattributes` pins LF endings for `.well-known/policy/*` to prevent CRLF-induced drift.
- `.gitignore` may exclude local backups and offline-only signature payloads.
