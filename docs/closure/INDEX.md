# TFWS v1.x Closure Index

This folder contains the canonical closure evidence for TFWS v1.x.
Goal: enable a third-party verifier (human or agent) to reproduce trust checks from repository artifacts.

## Canonical snapshot
- **Git tag:** `v1x-closure` (closure snapshot; repository is frozen at this tag)

## Evidence files

### Agent trust verdict (text)
- **File:** `AGENT_TRUST_VERDICT_2025-12-25.txt`
- **Proves:**
  - minisign public key was used as identity root
  - critical policy signatures verified (bundle/current/bounds)
  - bundle inventory integrity verified (sha256 for artifacts[])
  - per-artifact signature verification succeeded (sig_path minisigs)

### Agent trust verdict (machine-readable)
- **File:** `agent_verdict_2025-12-25.json`
- **Proves:**
  - same as the text verdict, but structured for ingestion by automation/agents

### Local archive signature handling
- **File:** `ARCHIVE_SIGNATURE_NOTE_2025-12-25.txt`
- **Proves:**
  - why `archive/*.minisig` may be intentionally excluded from git
  - how to verify the locally-held archive payload + signature

## Recommended verification commands (repro)

### A) Verify the identity root (public key)
- Inspect: `.well-known/minisign.pub`

### B) Verify critical signatures (k1-provider or non-KID)
Example (choose the signature variant you use):
- `minisign -Vm .well-known/policy/current.json -P <PUB> -x .well-known/policy/sigs/current.json.k1-provider.minisig`
- `minisign -Vm .well-known/policy/bounds.json  -P <PUB> -x .well-known/policy/sigs/bounds.json.k1-provider.minisig`
- `minisign -Vm .well-known/policy/policy.bundle.json -P <PUB> -x .well-known/policy/sigs/policy.bundle.json.k1-provider.minisig`

### C) Verify bundle inventory integrity (sha256)
- Compare `policy.bundle.json` → `artifacts[].sha256` vs local file hashes
- Note: `policy.bundle.json` self-hash entry is cyclic by design and may be skipped

### D) Verify per-artifact signatures from bundle (Level 3)
- Run: `tools/agent_level3_verify.sh`

## Notes
- `.gitattributes` pins LF endings for `.well-known/policy/*` to prevent CRLF-induced drift.
- `.gitignore` may exclude local backups and offline-only signature payloads.
