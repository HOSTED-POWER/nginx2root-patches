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
    previous_hotfix_release=${CENTOS8_HOTFIX_RELEASE%2}1
    next="$CENTOS8_EPOCH:$CENTOS8_VERSION-$CENTOS8_NEXT_RELEASE"

    "$python" - "$CENTOS8_EPOCH" "$CENTOS8_VERSION" \
        "$CENTOS8_BASE_RELEASE" "$previous_hotfix_release" \
        "$CENTOS8_HOTFIX_RELEASE" \
        "$CENTOS8_NEXT_RELEASE" <<'PY'
import rpm
import sys

epoch, version, base, previous, hotfix, following = sys.argv[1:]
assert rpm.labelCompare((epoch, version, base), (epoch, version, hotfix)) < 0
assert rpm.labelCompare((epoch, version, previous), (epoch, version, hotfix)) < 0
assert rpm.labelCompare((epoch, version, hotfix), (epoch, version, following)) < 0
PY
    echo "PASS: $base < $hotfix < $next"
done
