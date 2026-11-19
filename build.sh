#!/bin/bash
# Build and test all package sets in clean containers.
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

for release in 8 9 10 11 12 13; do
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

rpm_output="$OUT/centos7"
mkdir -p "$rpm_output"
docker run --rm \
    -v "$ROOT:/project:ro" \
    -v "$SOURCES:/sources:ro" \
    -v "$rpm_output:/out" \
    centos:7 \
    /project/scripts/build-rpm.sh /sources /out
docker run --rm \
    -v "$ROOT:/project:ro" \
    -v "$rpm_output:/out:ro" \
    centos:7 \
    /project/scripts/test-rpm-package.sh /out

echo "PASS: Debian 8 through 13 and CentOS 7 packages built and tested under $OUT"
