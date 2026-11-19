#!/bin/bash
set -euo pipefail
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"

python=/usr/libexec/platform-python
[ -x "$python" ] || python=python3

for stream in 1.14 1.16 1.18 1.20; do
    centos8_nginx_release_vars "$stream"
    base="$CENTOS8_EPOCH:$CENTOS8_VERSION-$CENTOS8_BASE_RELEASE"
    hotfix="$CENTOS8_EPOCH:$CENTOS8_VERSION-$CENTOS8_HOTFIX_RELEASE"
    hp1_release=${CENTOS8_HOTFIX_RELEASE%3}1
    hp2_release=${CENTOS8_HOTFIX_RELEASE%3}2
    next="$CENTOS8_EPOCH:$CENTOS8_VERSION-$CENTOS8_NEXT_RELEASE"

    "$python" - "$CENTOS8_EPOCH" "$CENTOS8_VERSION" \
        "$CENTOS8_BASE_RELEASE" "$hp1_release" "$hp2_release" \
        "$CENTOS8_HOTFIX_RELEASE" \
        "$CENTOS8_NEXT_RELEASE" <<'PY'
import rpm
import sys

epoch, version, base, hp1, hp2, hotfix, following = sys.argv[1:]
assert rpm.labelCompare((epoch, version, base), (epoch, version, hotfix)) < 0
assert rpm.labelCompare((epoch, version, hp1), (epoch, version, hp2)) < 0
assert rpm.labelCompare((epoch, version, hp2), (epoch, version, hotfix)) < 0
assert rpm.labelCompare((epoch, version, hotfix), (epoch, version, following)) < 0
PY
    echo "PASS: $base < $hotfix < $next"
done
