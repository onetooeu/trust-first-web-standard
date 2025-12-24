#!/usr/bin/env bash
# Verify M-of-N minisign signatures for required objects (per-kid supported).
set -euo pipefail

POLICY_DIR="${POLICY_DIR:-.well-known/policy}"
DUMPS_DIR="${DUMPS_DIR:-dumps}"
SIGS_POLICY_DIR="${SIGS_POLICY_DIR:-$POLICY_DIR/sigs}"
SIGS_DUMPS_DIR="${SIGS_DUMPS_DIR:-$DUMPS_DIR/sigs}"

MINISIGN_BIN="${MINISIGN_BIN:-minisign}"
JQ="${JQ:-jq}"

have(){ command -v "$1" >/dev/null 2>&1; }
die(){ echo "ERROR: $*" >&2; exit 1; }

have "$JQ" || die "jq missing"
have "$MINISIGN_BIN" || die "minisign missing"

QUORUM_FILE="$POLICY_DIR/quorum.json"
[[ -f "$QUORUM_FILE" ]] || die "Missing $QUORUM_FILE"

M="$("$JQ" -r '.quorum.m' "$QUORUM_FILE")"
N="$("$JQ" -r '.quorum.n' "$QUORUM_FILE")"

echo "== Verify quorum signatures (m=$M of n=$N) =="

FAIL=0

# Normalize object path -> (file_path, sig_dir, sig_basename)
resolve_obj() {
  local obj="$1"
  # strip leading slash
  local rel="${obj#/}"
  if [[ "$rel" == dumps/* ]]; then
    echo "$rel|$SIGS_DUMPS_DIR|$(basename "$rel")"
  else
    echo "$rel|$SIGS_POLICY_DIR|$(basename "$rel")"
  fi
}

# Verify one (file, sig, pubkey). Return 0 if ok.
verify_one() {
  local file="$1" sig="$2" pub="$3"
  "$MINISIGN_BIN" -Vm "$file" -x "$sig" -P "$pub" >/dev/null 2>&1
}

# Iterate required objects
mapfile -t OBJECTS < <("$JQ" -r '.objects_requiring_quorum[]' "$QUORUM_FILE")

for obj in "${OBJECTS[@]}"; do
  IFS='|' read -r file sigdir base <<<"$(resolve_obj "$obj")"
  if [[ ! -f "$file" ]]; then
    echo "⚠️  $obj -> missing file ($file)"
    FAIL=1
    continue
  fi

  v=0
  # keys: kid + pubkey
  while IFS=$'\t' read -r kid pub; do
    [[ -n "$kid" && -n "$pub" ]] || continue

    # Prefer per-kid signature; fallback to legacy <base>.minisig
    sig_kid="$sigdir/$base.$kid.minisig"
    sig_legacy="$sigdir/$base.minisig"

    if [[ -f "$sig_kid" ]]; then
      if verify_one "$file" "$sig_kid" "$pub"; then
        v=$((v+1))
      fi
    elif [[ -f "$sig_legacy" ]]; then
      if verify_one "$file" "$sig_legacy" "$pub"; then
        v=$((v+1))
      fi
    fi
  done < <("$JQ" -r '.keys[] | [.kid, .pubkey] | @tsv' "$QUORUM_FILE")

  if [[ "$v" -ge "$M" ]]; then
    echo "✅ $obj -> $v valid signatures"
  else
    echo "⚠️  $obj -> only $v valid signatures (need $M)"
    FAIL=1
  fi
done

[[ "$FAIL" -eq 0 ]] || die "Quorum verification failed"
echo "OK: quorum verification passed"
