# Release Notes — v1.8.3 (TFWS)

v1.8.3 finalizes the TFWS v1.x policy tooling behavior around publishing and verification.  
The release strengthens correctness and reproducibility by ensuring the policy publication path is deterministic, while keeping ephemeral verification output out of the signed, long-term artifact set.

Key changes:
- **publish_policy hard-verify repaired:** public key parsing and signature verification are restored and enforced immediately after signing.
- **Ephemeral verification report excluded from signing:** `verification.report.json` is treated as runtime output and is never included in the signed policy artifacts.
- **Verify-only workflow stabilized:** verification can be run without mutating the signed state, and emits a small report intended for operators and CI visibility.
