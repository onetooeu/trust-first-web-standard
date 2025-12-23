# TFWS-AP Policy Lab – Requirements (Windows/macOS/Linux)

This repo workflow signs and verifies JSON artifacts using **minisign** and requires a few standard CLI tools.

## Mandatory tools

- **Git** (repo operations)
- **Python 3.11+** (policy runner tools)
- **jq** (canonical JSON + validation)
- **minisign** (Ed25519 signatures; required)
- **curl** (optional but strongly recommended; fetch/health checks)
- A SHA-256 tool:
  - Linux: `sha256sum`
  - macOS: `shasum -a 256`

## Optional (nice-to-have)

- Node.js (only if you later add build tooling)
- Cloudflare CLI `wrangler` (Pages automation)

---

## Windows (recommended: winget)

Run in **PowerShell**:

```powershell
winget install --id Git.Git -e
winget install --id Python.Python.3.11 -e
winget install --id jqlang.jq -e
```

For **minisign** on Windows (choose one):

1) **Scoop**:
```powershell
iwr -useb get.scoop.sh | iex
scoop install minisign
```

2) **Chocolatey** (if you already use it):
```powershell
choco install minisign -y
```

Verify:
```powershell
git --version
python --version
jq --version
minisign -v
```

---

## macOS (Homebrew)

```bash
brew install git python jq minisign
```

---

## Debian/Ubuntu

```bash
sudo apt update
sudo apt install -y git python3 jq minisign curl
```

---

## First run check

```bash
tools/policy/bootstrap_check.sh
```

---

## Signing keys

- Keep private keys **out of git** (recommended location):
  - `./.secrets/minisign.key`
- Public keys live in:
  - `/.well-known/minisign.pub` and/or `/.well-known/policy/quorum.json`

> Tip: each signer runs `publish_policy.sh` with its own key and `KID=...` so signatures become `*.json.<kid>.minisig`.
