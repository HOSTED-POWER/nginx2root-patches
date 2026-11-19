#!/bin/bash
set -euo pipefail
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"

compare_release() {
    local left=$1 expected=$2 right=$3 result
    result=$(python - "$CENTOS7_EPEL_EPOCH" "$CENTOS7_EPEL_VERSION" \
        "$left" "$right" <<'PY'
import rpm
import sys

epoch, version, left, right = sys.argv[1:]
print(rpm.labelCompare((epoch, version, left), (epoch, version, right)))
PY
)
    [ "$result" = "$expected" ] || {
        echo "FAIL: $left comparison with $right returned $result" >&2
        exit 1
    }
    printf 'PASS: %s:%s-%s < %s:%s-%s\n' \
        "$CENTOS7_EPEL_EPOCH" "$CENTOS7_EPEL_VERSION" "$left" \
        "$CENTOS7_EPEL_EPOCH" "$CENTOS7_EPEL_VERSION" "$right"
}

compare_release "$CENTOS7_EPEL_BASE_RELEASE" -1 "$CENTOS7_EPEL_HOTFIX_RELEASE"
compare_release "${CENTOS7_EPEL_HOTFIX_RELEASE%3}1" -1 "${CENTOS7_EPEL_HOTFIX_RELEASE%3}2"
compare_release "${CENTOS7_EPEL_HOTFIX_RELEASE%3}2" -1 "$CENTOS7_EPEL_HOTFIX_RELEASE"
compare_release "$CENTOS7_EPEL_HOTFIX_RELEASE" -1 "$CENTOS7_EPEL_POINT_RELEASE"
compare_release "$CENTOS7_EPEL_HOTFIX_RELEASE" -1 "$CENTOS7_EPEL_NEXT_RELEASE"
