#!/usr/bin/env bash
set -euo pipefail

PUB="$(awk 'NF{gsub(/\r/,""); if($0 ~ /^RW[0-9A-Za-z+\/=]+$/){print; exit}}' .well-known/minisign.pub)"
B=".well-known/policy/policy.bundle.json"

echo "== TFWS Agent Level 3: verify sig_path entries with minisign =="
echo "PUB=$PUB"
echo "BUNDLE=$B"
echo

# quick sanity: show first few sig files and their first line
echo "== Sanity: sample signature headers =="
for s in .well-known/policy/sigs/*.minisig; do
  head -n 1 "$s" | sed "s|^|$(basename "$s"): |"
  break
done
echo

FAIL=0
COUNT=0
OK=0
SKIP=0

# Note: use minisign -V (not -Vm) for generic signatures.
while IFS=$'\t' read -r p sp; do
  p="$(printf '%s' "$p"  | tr -d '\r')"
  sp="$(printf '%s' "$sp" | tr -d '\r')"

  if [ "$p" = "/.well-known/policy/policy.bundle.json" ]; then
    echo "SKIP  $p (self)"
    SKIP=$((SKIP+1))
    continue
  fi

  f=".${p}"
  s=".${sp}"
  COUNT=$((COUNT+1))

  if [ ! -f "$f" ]; then
    echo "MISSING FILE  $p"
    FAIL=1
    continue
  fi
  if [ ! -f "$s" ]; then
    echo "MISSING SIG   $sp"
    FAIL=1
    continue
  fi

  if minisign -V -P "$PUB" -m "$f" -x "$s" >/dev/null 2>&1; then
    echo "OK    $p"
    OK=$((OK+1))
  else
    echo "BAD   $p"
    echo "      sig: $sp"
    minisign -V -P "$PUB" -m "$f" -x "$s" 2>&1 | sed -n '1,6p'
    FAIL=1
  fi
done < <(jq -r '.artifacts[] | "\(.path)\t\(.sig_path)"' "$B")

echo
echo "Checked: $COUNT | OK: $OK | Skipped: $SKIP"
if [ "$FAIL" -eq 0 ]; then
  echo "LEVEL 3 VERDICT: PASS"
else
  echo "LEVEL 3 VERDICT: FAIL"
  exit 2
fi
