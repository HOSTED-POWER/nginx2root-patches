#!/bin/bash
# Build and test the native Rocky Linux 8 package family.
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
. "$ROOT/versions.sh"
SOURCES=$(realpath -m "${SOURCES:-$ROOT/sources}")
OUT=$(realpath -m "${OUT:-$ROOT/out}")

command -v docker >/dev/null 2>&1 || {
    echo 'docker is required' >&2
    exit 1
}

mkdir -p "$SOURCES" "$OUT/el8"
"$ROOT/scripts/fetch-sources.sh" "$SOURCES" el8

while IFS= read -r target; do
    el9_nginx_release_vars "$target"
    output="$OUT/el8/$EL9_VENDOR/$EL9_STREAM"
    if [ "$EL9_VENDOR" = rhel ]; then
        image="$EL9_IMAGE:latest"
    else
        image="$EL9_IMAGE:$EL9_IMAGE_TAG"
    fi
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
done < <(el8_targets)

echo "PASS: all EL8 package families built and tested under $OUT/el8"
