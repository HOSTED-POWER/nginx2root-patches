#!/bin/bash
set -euo pipefail
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"

compare() {
    local left=$1 operator=$2 right=$3
    dpkg --compare-versions "$left" "$operator" "$right"
    printf 'PASS: %s %s %s\n' "$left" "$operator" "$right"
}

for release in 8 9 10 11 12 13; do
    nginx_release_vars "$release"
    case "$HOTFIX_VERSION" in
        *:*) echo "FAIL: epoch must not be introduced: $HOTFIX_VERSION" >&2; exit 1 ;;
    esac
    previous_hotfix_version=${HOTFIX_VERSION%2}1
    compare "$BASE_VERSION" lt "$HOTFIX_VERSION"
    compare "$previous_hotfix_version" lt "$HOTFIX_VERSION"
    compare "$HOTFIX_VERSION" lt "$DEBIAN_POINT_VERSION"
    compare "$HOTFIX_VERSION" lt "$DEBIAN_NEXT_VERSION"
done
