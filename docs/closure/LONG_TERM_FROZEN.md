# Long-Term Frozen Declaration — TFWS v1.x

**Status:** LONG-TERM FROZEN  
**Effective date:** 2025-12-24  
**Repository:** `onetooeu/trust-first-web-standard`

## What “long-term frozen” means

TFWS v1.x is declared **long-term frozen**. This means:

- The repository state is **read-only by intent**.
- The v1.x structure and outputs are suitable for **archival, audits, and reference use**.
- Changes that would modify v1.x behavior, semantics, or verification expectations are **not accepted**.

## Allowed changes (exception policy)

Only the following may be considered, and only if unavoidable:

1. **Non-semantic documentation corrections**  
   (typos, clarity improvements, formatting) that do not alter technical meaning.

2. **Critical security communications**  
   published as additive documentation (e.g., advisories), without changing v1.x rules.

3. **Packaging or mirror conveniences**  
   that do not modify any signed artifact content and do not change canonical paths.

Any exception must be explicitly documented and must preserve v1.x verifiability.

## Forward evolution

All future evolution must start as **TFWS v2.x** (new major series), with:
- explicit versioning,
- explicit migration notes,
- explicit cryptographic and policy changes.

— EOF
