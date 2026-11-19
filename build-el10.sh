#!/bin/bash
# Build and test the native Oracle Linux 10 package family.
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
. "$ROOT/versions.sh"
SOURCES=$(realpath -m "${SOURCES:-$ROOT/sources}")
OUT=$(realpath -m "${OUT:-$ROOT/out}")

command -v docker >/dev/null 2>&1 || {
    echo 'docker is required' >&2
    exit 1
}

mkdir -p "$SOURCES" "$OUT/el10"
"$ROOT/scripts/fetch-sources.sh" "$SOURCES"

while IFS= read -r target; do
    el9_nginx_release_vars "$target"
    output="$OUT/el10/$EL9_VENDOR/$EL9_STREAM"
    image="$EL9_IMAGE:$EL9_MAJOR"
    mkdir -p "$output"
    docker run --rm --hostname packages.hosted-power.com \
        -v "$ROOT:/project:ro" \
        -v "$SOURCES:/sources:ro" \
        -v "$output:/out" \
        "$image" \
        /project/scripts/build-el9-rpm.sh /sources /out "$target"
    docker run --rm \
        -v "$ROOT:/project:ro" \
        -v "$output:/out:ro" \
        "$image" \
        /project/scripts/test-el9-rpm-package.sh /out "$target"
done < <(el10_targets)

echo "PASS: all required EL10 package families built and tested under $OUT/el10"
