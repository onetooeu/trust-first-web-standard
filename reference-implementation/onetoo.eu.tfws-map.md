# onetoo.eu — TFWS Compliance Map

This document maps a real deployment (onetoo.eu) to TFWS requirements.

## Declared profile
- Target: **TFWS-Verified** (Core + Signing)

## Core endpoints (§6)
- `/.well-known/llms.txt` — implemented
- `/.well-known/security.txt` — implemented
- `/robots.txt` — implemented
- `/sitemap.xml` — implemented
- Trust manifest `/.well-known/ai-trust-hub.json` — implemented

## Signing & Integrity (§7)
- `/.well-known/minisign.pub` — implemented
- Detached signatures (`.minisig`) — implemented
- Hash index (`sha256.json`) — implemented and signed

## Notes
- Trust-critical documents are treated as immutable releases.
- Any change increments version and updates signatures and hashes.
