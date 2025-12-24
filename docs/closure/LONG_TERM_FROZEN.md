# Long-Term Frozen — TFWS v1.x

**Status:** LONG-TERM FROZEN (LTF)  
**Series:** Trust-First Web Standard (TFWS) v1.x (v1.0.0 through v1.8.3)  
**Effective date:** 2025-12-24  
**Repository:** `onetooeu/trust-first-web-standard`  
**Canonical closure:** `docs/closure/TRUST_CLOSURE_STATEMENT.md`

## Meaning of “Long-Term Frozen”

“Long-Term Frozen” means the TFWS v1.x series is intentionally kept stable and unchanged for long-term interoperability, archival integrity, and third-party auditability.

This status is a project policy statement describing how the maintainers will treat the v1.x series going forward.

## What will NOT change in v1.x

The following are frozen for TFWS v1.x:

- **Semantics and validation rules** (what documents mean and how they verify)
- **Canonical paths and artifact layout** required for verification and audit rails
- **Cryptographic verification expectations** (hash inventory + signature verification model)
- **Published signed releases** and their historical verification properties

No future changes are planned that would introduce backwards-affecting behavior for v1.x.

## Allowed changes (exception-only)

Only the following changes may occur in v1.x, and only if strictly necessary:

- **Additive clarifications** to documentation that do not change meaning or validation behavior
- **Security advisories** and operational notices that do not modify v1.x semantics
- **Additive audit metadata** that preserves existing verification for historical releases

If an exception is required, it must be:
- explicitly documented,
- narrowly scoped,
- and must not silently invalidate historical releases.

## Where new work goes

All new functionality, new semantics, new trust signals, or behavioral changes must start as **TFWS v2.x** (new major series), with explicit versioning and migration guidance.

## Sign-off

Issued by the TFWS maintainers for the TFWS v1.x series.

— EOF
