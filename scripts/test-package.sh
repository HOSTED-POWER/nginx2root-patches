#!/bin/bash
# test.sh <out-dir>   (run inside matching debian:12/13)
set -euo pipefail
OUT=$(realpath "$1")
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. /etc/os-release
nginx_release_vars "$VERSION_ID"
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    libnginx-mod-http-echo libnginx-mod-http-lua libnginx-mod-mail nginx nghttp2-client >/dev/null

installed_before=$(dpkg-query -W -f='${Version}' nginx)
[ "$installed_before" = "$BASE_VERSION" ] || {
    echo "expected Debian nginx $BASE_VERSION before upgrade, found $installed_before" >&2
    exit 1
}
abi_before=$(dpkg-query -W -f='${Provides}' nginx)
modules_before=$(dpkg-query -W -f='${binary:Package}\n' 'libnginx-mod-*' | sort)

nginx_deb="$OUT/nginx_${HOTFIX_VERSION}_amd64.deb"
common_deb="$OUT/nginx-common_${HOTFIX_VERSION}_all.deb"
mail_deb="$OUT/libnginx-mod-mail_${HOTFIX_VERSION}_amd64.deb"
[ -f "$nginx_deb" ] && [ -f "$common_deb" ] && [ -f "$mail_deb" ]
"$ROOT/install.sh" "$OUT"

[ "$(dpkg-query -W -f='${Version}' nginx)" = "$HOTFIX_VERSION" ]
[ "$(dpkg-query -W -f='${Version}' nginx-common)" = "$HOTFIX_VERSION" ]
[ "$(dpkg-query -W -f='${Version}' libnginx-mod-mail)" = "$HOTFIX_VERSION" ]
[ "$(dpkg-query -W -f='${Provides}' nginx)" = "$abi_before" ] || {
    echo "NGINX module ABI changed" >&2
    exit 1
}
[ "$(dpkg-query -W -f='${binary:Package}\n' 'libnginx-mod-*' | sort)" = "$modules_before" ] || {
    echo "installed dynamic module set changed during upgrade" >&2
    exit 1
}
nginx -t

for package in "$OUT"/*.deb; do
    [ "$(dpkg-deb -f "$package" Version)" = "$HOTFIX_VERSION" ]
done
dpkg --compare-versions "$HOTFIX_VERSION" lt "$DEBIAN_POINT_VERSION"
dpkg --compare-versions "$HOTFIX_VERSION" lt "$DEBIAN_NEXT_VERSION"

SMOKE=$(mktemp -d)
mkdir -p "$SMOKE/html" "$SMOKE/logs"
printf 'nginx hotfix HTTP/2 smoke test\n' > "$SMOKE/html/index.html"
cat > "$SMOKE/nginx.conf" <<EOF
daemon off;
master_process off;
pid $SMOKE/nginx.pid;
error_log $SMOKE/logs/error.log info;
events {}
http {
    access_log off;
    server {
        listen 127.0.0.1:18080 http2;
        root $SMOKE/html;
    }
}
EOF
nginx -p "$SMOKE/" -c nginx.conf &
nginx_pid=$!
trap 'kill "$nginx_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 50); do
    if nghttp http://127.0.0.1:18080/ > "$SMOKE/response" 2>&1 \
        && grep -q 'nginx hotfix HTTP/2 smoke test' "$SMOKE/response"; then
        break
    fi
    sleep 0.1
done
grep -q 'nginx hotfix HTTP/2 smoke test' "$SMOKE/response"
kill "$nginx_pid"
wait "$nginx_pid" || true
trap - EXIT

echo "PASS: upgraded $BASE_VERSION -> $HOTFIX_VERSION with ABI $abi_before and working HTTP/2"
