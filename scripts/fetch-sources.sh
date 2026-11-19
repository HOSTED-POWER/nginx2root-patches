#!/bin/bash
# Fetch and verify the exact Debian/ELTS source material used for all hotfix builds.
set -euo pipefail
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
OUT=$(realpath -m "${1:-$ROOT/sources}")

mkdir -p "$OUT"

fetch() {
    local url=$1 file=$2 sha256=$3 temporary
    temporary="$OUT/.${file}.tmp"
    curl -fsSL --retry 3 -o "$temporary" "$url/$file"
    printf '%s  %s\n' "$sha256" "$temporary" | sha256sum --check --status || {
        rm -f "$temporary"
        echo "sha256 mismatch for $file" >&2
        exit 1
    }
    mv "$temporary" "$OUT/$file"
    printf '%s  %s\n' "$sha256" "$OUT/$file" | sha256sum --check
}

for release in 8 9 10 11 12 13; do
    nginx_release_vars "$release"
    fetch "$SOURCE_POOL" "$ORIG_FILE" "$ORIG_SHA256"
    fetch "$SOURCE_POOL" "$DEBIAN_FILE" "$DEBIAN_SHA256"
done

fetch "$CENTOS7_EPEL_SOURCE_POOL" "$CENTOS7_EPEL_SOURCE_FILE" \
    "$CENTOS7_EPEL_SOURCE_SHA256"

for stream in 1.14 1.16 1.18 1.20; do
    centos8_nginx_release_vars "$stream"
    fetch "$CENTOS8_SOURCE_POOL" "$CENTOS8_SOURCE_FILE" \
        "$CENTOS8_SOURCE_SHA256"
done

while IFS= read -r target; do
    el9_nginx_release_vars "$target"
    fetch "$EL9_SOURCE_URL" "$EL9_SOURCE_FILE" "$EL9_SOURCE_SHA256"
done < <(el9_targets)
