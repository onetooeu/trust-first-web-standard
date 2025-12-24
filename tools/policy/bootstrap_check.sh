#!/usr/bin/env bash
set -euo pipefail

die(){ echo "ERROR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

REQ=(git curl jq python3)
for b in "${REQ[@]}"; do
  have "$b" || die "Missing required tool: $b"
done

# sha tool
if ! have sha256sum && ! have shasum; then
  die "Need sha256sum (Linux) or shasum (macOS)"
fi

# minisign
have minisign || die "Missing minisign (required for signing + verification)"

echo "OK: core tools present"
minisign -v || true
python3 --version
jq --version
