#!/usr/bin/env bash
MINISIGN_KEY="${MINISIGN_KEY:-"$MINISIGN_KEY"}"
[[ -f "$MINISIGN_KEY" ]] || MINISIGN_KEY="$HOME/.minisign/minisign.key"
set -euo pipefail

BASE_DIR="${BASE_DIR:-.}"
POLICY_DIR="${POLICY_DIR:-$BASE_DIR/.well-known/policy}"
DUMPS_DIR="${DUMPS_DIR:-$BASE_DIR/dumps}"
SIGS_DIR="${SIGS_DIR:-$POLICY_DIR/sigs}"

MINISIGN_BIN="${MINISIGN_BIN:-minisign}"
MINISIGN_SECRET="${MINISIGN_SECRET:-$BASE_DIR/.secrets/minisign.key}"; [[ -f "$MINISIGN_SECRET" ]] || MINISIGN_SECRET="$HOME/.minisign/minisign.key" # keep out of git
KID="${KID:-}" # optional: signer key id (e.g., k1-provider). If set, signatures become <file>.<kid>.minisig

JQ="${JQ:-jq}"

mkdir -p "$POLICY_DIR" "$SIGS_DIR" "$DUMPS_DIR" "$DUMPS_DIR/sigs"

die(){ echo "ERROR: $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

if ! have "$JQ"; then die "jq missing"; fi
if ! have "$MINISIGN_BIN"; then die "minisign missing (required). Install minisign."; fi
if [[ ! -f "$MINISIGN_SECRET" ]]; then die "Missing minisign secret key at $MINISIGN_SECRET"; fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

canon_json() {
  local in="$1"
  "$JQ" -cS . "$in" > "$in.tmp" && mv "$in.tmp" "$in"
}

assert_bounds() {
  local bounds="$1" current="$2"
  local anyfalse
  anyfalse="$("$JQ" -r '
    def inrange($v; $min; $max): ($v >= $min) and ($v <= $max);
    . as $b | input as $c
    | ($b.params | keys[]) as $k
    | inrange($c.params[$k]; $b.params[$k].min; $b.params[$k].max)
  ' "$bounds" "$current" | grep -c false || true)"
  [[ "$anyfalse" -eq 0 ]] || die "Bounds check failed"
}

append_audit_event() {
  local audit="$1" object_path="$2" object_hash="$3" policy_version="$4"
  local prev_hash seq now event_hash
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  if [[ -f "$audit" ]]; then
    prev_hash="$("$JQ" -r '.head.event_hash_sha256 // "0000000000000000000000000000000000000000000000000000000000000000"' "$audit")"
    seq="$("$JQ" -r '.head.seq // 0' "$audit")"
    seq=$((seq+1))
  else
    prev_hash="0000000000000000000000000000000000000000000000000000000000000000"
    seq=1
    echo '{"schema":"tfws-ap.audit.merkle.v1","policy_id":"onetoo.eu/trust-policy","head":null,"events":[]}' > "$audit"
  fi

  event_hash="$(printf "%s|%s|%s|%s|%s|%s|%s" \
      "$seq" "$now" "publish_policy" "$object_path" "$object_hash" "$prev_hash" "$policy_version" \
    | (command -v sha256sum >/dev/null 2>&1 && sha256sum || shasum -a 256) | awk '{print $1}')"

  "$JQ" -cS --arg now "$now" --arg obj "$object_path" --arg oh "$object_hash" \
      --arg prev "$prev_hash" --arg eh "$event_hash" --arg pv "$policy_version" --argjson seq "$seq" '
    .events += [{
      seq:$seq,
      ts_utc:$now,
      event_type:"publish_policy",
      object:$obj,
      object_hash_sha256:$oh,
      prev_hash_sha256:$prev,
      event_hash_sha256:$eh,
      meta:{policy_version:$pv}
    }]
    | .head = .events[-1]
  ' "$audit" > "$audit.tmp" && mv "$audit.tmp" "$audit"
}

sign_file() {
  local file="$1" sig="$2"
  "$MINISIGN_BIN" -Sm "$file" -s "$MINISIGN_SECRET" -x "$sig" >/dev/null
}

update_dumps_sha256() {
  local out="$1"
  local tmp
  tmp="$(mktemp)"
  echo '{"schema":"tfws.sha256.inventory.v1","generated_utc":"","files":[]}' > "$tmp"

  local now
  now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  "$JQ" --arg now "$now" '.generated_utc=$now' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"

  add_file () {
    local p="$1"
    local path="/${p#./}"
    local h s
    h="$(sha256_file "$p")"
    s="$(wc -c < "$p" | tr -d ' ')"
    "$JQ" -cS --arg path "$path" --arg sha "$h" --argjson size "$s" \
      '.files += [{"path":$path,"sha256":$sha,"size":$size}]' "$tmp" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
  }

  # Include policy artifacts
  while IFS= read -r f; do add_file "$f"; done < <(find ./.well-known/policy -type f -name "*.json" | sort)

  # Include core trust artifacts relevant to ONETOO
  for f in "./.well-known/ai-trust-hub.json" "./status.json" "./openapi.json" "./api/v1/openapi.json" "./dumps/release.json"; do
    [[ -f "$f" ]] && add_file "$f" || true
  done

  "$JQ" -cS '.files |= sort_by(.path)' "$tmp" > "$out"
  rm -f "$tmp"
}

echo "== Canonicalize policy JSON =="
for f in "$POLICY_DIR"/*.json; do canon_json "$f"; done

echo "== Validate JSON parse =="
for f in "$POLICY_DIR"/*.json; do "$JQ" -e . "$f" >/dev/null; done

echo "== Bounds validation =="
assert_bounds "$POLICY_DIR/bounds.json" "$POLICY_DIR/current.json"

echo "== Append audit event for current.json =="
POLICY_VERSION="$("$JQ" -r '.policy_version' "$POLICY_DIR/current.json")"
CUR_HASH="$(sha256_file "$POLICY_DIR/current.json")"
append_audit_event "$POLICY_DIR/audit.merkle.json" "/.well-known/policy/current.json" "$CUR_HASH" "$POLICY_VERSION"
canon_json "$POLICY_DIR/audit.merkle.json"

echo "== Sign policy artifacts =="
for f in "$POLICY_DIR"/*.json; do
  base="$(basename "$f")"
  if [[ -n "$KID" ]]; then
    sign_file "$f" "$SIGS_DIR/$base.$KID.minisig"
  else
    sign_file "$f" "$SIGS_DIR/$base.minisig"
  fi
done

echo "== Update dumps/sha256.json + sign =="
update_dumps_sha256 "$DUMPS_DIR/sha256.json"
canon_json "$DUMPS_DIR/sha256.json"
if [[ -n "$KID" ]]; then
  sign_file "$DUMPS_DIR/sha256.json" "$DUMPS_DIR/sigs/sha256.json.$KID.minisig"
else
  sign_file "$DUMPS_DIR/sha256.json" "$DUMPS_DIR/sigs/sha256.json.minisig"
fi

echo "DONE: policy published locally (minisign signatures generated)."
