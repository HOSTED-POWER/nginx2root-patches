#!/bin/bash
# Build and test all currently supported Debian package sets in clean containers.
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
SOURCES=$(realpath -m "${SOURCES:-$ROOT/sources}")
OUT=$(realpath -m "${OUT:-$ROOT/out}")

command -v docker >/dev/null 2>&1 || {
    echo 'docker is required' >&2
    exit 1
}

mkdir -p "$SOURCES" "$OUT"
"$ROOT/scripts/fetch-sources.sh" "$SOURCES"
"$ROOT/scripts/test-version-order.sh"

for release in 9 10 11 12 13; do
    output="$OUT/debian$release"
    mkdir -p "$output"
    docker run --rm \
        -v "$ROOT:/project:ro" \
        -v "$SOURCES:/sources:ro" \
        -v "$output:/out" \
        "debian:$release" \
        /project/scripts/build-deb.sh /sources /out
    docker run --rm \
        -v "$ROOT:/project:ro" \
        -v "$output:/out:ro" \
        "debian:$release" \
        /project/scripts/test-package.sh /out
done

echo "PASS: Debian 9 through 13 packages built and tested under $OUT"
