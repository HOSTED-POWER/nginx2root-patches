#!/bin/bash
# Build and test all native EL9 package families in parallel.
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
. "$ROOT/versions.sh"
SOURCES=$(realpath -m "${SOURCES:-$ROOT/sources}")
OUT=$(realpath -m "${OUT:-$ROOT/out}")
JOBS=${JOBS:-2}

command -v docker >/dev/null 2>&1 || {
    echo 'docker is required' >&2
    exit 1
}

mkdir -p "$SOURCES" "$OUT/el9"
"$ROOT/scripts/fetch-sources.sh" "$SOURCES"

run_el9_target() {
    set -euo pipefail
    local target=$1 output image
    . "$ROOT/versions.sh"
    el9_nginx_release_vars "$target"
    output="$OUT/el9/$EL9_VENDOR/$EL9_STREAM"
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
}
export -f run_el9_target
export ROOT SOURCES OUT

el9_targets | xargs -r -n1 -P "$JOBS" bash -c 'run_el9_target "$1"' _
echo "PASS: all EL9 package families built and tested under $OUT/el9"
