# ONETOO.eu — AI Trust Hub

> ⚠️ **TFWS v1.x is COMPLETE and LONG-TERM FROZEN** — canonical closure: `docs/closure/TRUST_CLOSURE_STATEMENT.md` (final release tooling: `v1.8.3`).

This repository is a **static, audit-friendly trust & governance hub** designed for:
- AI agents (machine-readable trust manifest + OpenAPI)
- partners & auditors (verification, integrity inventory, incident & changelog rails)
- humans (clear, transparent landing pages)

---

## What this repository ships

### Human entrypoints
- `/` (index)
- `/ai-trust-hub.html`
- `/verify.html`

### Machine entrypoints
- `/.well-known/ai-trust-hub.json`
- `/.well-known/llms.txt`
- `/.well-known/minisign.pub`
- `/dumps/sha256.json`
- `/dumps/sigs/*.minisig`

---

## Golden rules (the “Mozart mode”)

1. **Everything that matters is linkable**  
   Stable URLs, no hidden knowledge.

2. **Everything that ships is hashable**  
   Canonical inventory in `dumps/sha256.json`.

3. **Everything that’s hashable is signable**  
   Cryptographic signatures via Minisign.

4. **Everything is machine-readable first**  
   JSON / OpenAPI first, human-friendly second.

---

## Local workflow

```bash
python3 scripts/generate_dumps.py
bash scripts/verify_local.sh

> 🔖 Closure snapshot tag: `v1x-closure` (points to the frozen v1.x closure commit)
