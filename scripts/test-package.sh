#!/bin/bash
# test-package.sh <out-dir>   (run inside matching Debian container)
set -euo pipefail
OUT=$(realpath "$1")
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$ROOT/scripts/configure-legacy-apt.sh"
. /etc/os-release
nginx_release_vars "$VERSION_ID"
export DEBIAN_FRONTEND=noninteractive

configure_legacy_apt "$VERSION_ID" "$RELEASE_CODENAME"
apt-get update -qq
if [ "$VERSION_ID" = 8 ]; then
    apt-get install -y -qq --no-install-recommends curl nginx-extras >/dev/null
else
    apt-get install -y -qq --no-install-recommends \
        curl libnginx-mod-http-echo libnginx-mod-http-lua libnginx-mod-mail \
        libnginx-mod-stream nginx nghttp2-client >/dev/null
fi

if [ "$VERSION_ID" -ge 12 ]; then
    nginx_binary_package=nginx
else
    nginx_binary_package=$(
        { dpkg-query -W -f='${binary:Package} ${db:Status-Status}\n' \
            nginx-core nginx-full nginx-light nginx-extras 2>/dev/null || true; } \
            | awk '$2 == "installed" { print $1 }' | head -1
    )
fi
[ -n "$nginx_binary_package" ] || {
    echo 'could not identify the installed NGINX binary package' >&2
    exit 1
}
installed_before=$(dpkg-query -W -f='${Version}' "$nginx_binary_package")
[ "$installed_before" = "$BASE_VERSION" ] || {
    echo "expected Debian NGINX $BASE_VERSION before upgrade, found $installed_before" >&2
    exit 1
}
abi_before=$(dpkg-query -W -f='${Provides}' "$nginx_binary_package")
if [ "$VERSION_ID" = 8 ]; then
    modules_before=''
else
    modules_before=$(dpkg-query -W -f='${binary:Package}\n' 'libnginx-mod-*' | sort)
fi

nginx_deb=$(find "$OUT" -maxdepth 1 -type f \
    \( -name "nginx_${HOTFIX_VERSION}_*.deb" -o \
       -name "nginx-extras_${HOTFIX_VERSION}_*.deb" -o \
       -name "nginx-full_${HOTFIX_VERSION}_*.deb" -o \
       -name "nginx-light_${HOTFIX_VERSION}_*.deb" \) -print -quit)
common_deb="$OUT/nginx-common_${HOTFIX_VERSION}_all.deb"
[ -n "$nginx_deb" ] && [ -f "$nginx_deb" ] && [ -f "$common_deb" ]
if [ "$VERSION_ID" -ge 9 ]; then
    mail_deb="$OUT/libnginx-mod-mail_${HOTFIX_VERSION}_amd64.deb"
    [ -f "$mail_deb" ]
fi
"$ROOT/install.sh" "$OUT"

[ "$(dpkg-query -W -f='${Version}' nginx-common)" = "$HOTFIX_VERSION" ]
if [ "$VERSION_ID" -ge 9 ]; then
    [ "$(dpkg-query -W -f='${Version}' libnginx-mod-mail)" = "$HOTFIX_VERSION" ]
fi
[ "$(dpkg-query -W -f='${Version}' "$nginx_binary_package")" = "$HOTFIX_VERSION" ]
[ "$(dpkg-query -W -f='${Provides}' "$nginx_binary_package")" = "$abi_before" ] || {
    echo "NGINX module ABI changed" >&2
    exit 1
}
if [ "$VERSION_ID" -ge 9 ]; then
    [ "$(dpkg-query -W -f='${binary:Package}\n' 'libnginx-mod-*' | sort)" = "$modules_before" ] || {
        echo "installed dynamic module set changed during upgrade" >&2
        exit 1
    }
fi
nginx -t

for package in "$OUT"/*.deb; do
    [ "$(dpkg-deb -f "$package" Version)" = "$HOTFIX_VERSION" ]
done
dpkg --compare-versions "$HOTFIX_VERSION" lt "$DEBIAN_POINT_VERSION"
dpkg --compare-versions "$HOTFIX_VERSION" lt "$DEBIAN_NEXT_VERSION"

SMOKE=$(mktemp -d)
mkdir -p "$SMOKE/html" "$SMOKE/logs"
chmod 0755 "$SMOKE" "$SMOKE/html"
printf 'nginx hotfix backend response\n' > "$SMOKE/html/index.html"
cat > "$SMOKE/nginx.conf" <<EOF
include /etc/nginx/modules-enabled/*.conf;
daemon off;
master_process on;
worker_processes 2;
pid $SMOKE/nginx.pid;
error_log $SMOKE/logs/error.log info;
events {}
http {
    access_log off;
    server {
        listen 127.0.0.1:18081;
        root $SMOKE/html;
    }
    server {
        listen 127.0.0.1:18080;
        location /proxy {
            proxy_pass http://127.0.0.1:18081/;
        }
        location /echo {
            echo "nginx hotfix echo module";
        }
        location /lua {
            content_by_lua 'ngx.say("nginx hotfix lua module")';
        }
    }
    server {
        listen 127.0.0.1:18082${HTTP2_LISTEN:-};
        return 200 "nginx hotfix HTTP/2 response\n";
    }
}
mail {
    auth_http 127.0.0.1:18081/auth;
    server {
        listen 127.0.0.1:18025;
        protocol smtp;
        smtp_auth none;
    }
}
EOF
if [ "$VERSION_ID" -ge 9 ]; then
    HTTP2_LISTEN=' http2'
    cat >> "$SMOKE/nginx.conf" <<'EOF'
stream {
    server {
        listen 127.0.0.1:18083;
        proxy_pass 127.0.0.1:18081;
    }
}
EOF
else
    HTTP2_LISTEN=''
fi
sed -i "s/18082;/18082$HTTP2_LISTEN;/" "$SMOKE/nginx.conf"
nginx -c "$SMOKE/nginx.conf" -t
nginx -c "$SMOKE/nginx.conf" &
nginx_pid=$!
trap 'kill "$nginx_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 50); do
    if curl -fsS http://127.0.0.1:18080/proxy > "$SMOKE/proxy-response" \
        && grep -q 'nginx hotfix backend response' "$SMOKE/proxy-response"; then
        break
    fi
    sleep 0.1
done
grep -q 'nginx hotfix backend response' "$SMOKE/proxy-response"
curl -fsS http://127.0.0.1:18080/echo | grep -q 'nginx hotfix echo module'
curl -fsS http://127.0.0.1:18080/lua | grep -q 'nginx hotfix lua module'

worker_count=0
for status_file in /proc/[0-9]*/status; do
    worker_parent=$(awk '$1 == "PPid:" { print $2 }' "$status_file" 2>/dev/null || true)
    if [ "$worker_parent" = "$nginx_pid" ]; then
        worker_count=$((worker_count + 1))
    fi
done
[ "$worker_count" -eq 2 ] || {
    echo "expected two fresh NGINX workers, found $worker_count" >&2
    exit 1
}

smtp_greeting=$(
    exec 3<>/dev/tcp/127.0.0.1/18025
    IFS= read -r line <&3
    printf '%s\n' "$line"
)
printf '%s\n' "$smtp_greeting" | grep -q '^220 '

if [ "$VERSION_ID" -ge 9 ]; then
    nghttp http://127.0.0.1:18082/ 2>&1 | grep -q 'nginx hotfix HTTP/2 response'
    curl -fsS http://127.0.0.1:18083/ | grep -q 'nginx hotfix backend response'
fi
kill "$nginx_pid"
wait "$nginx_pid" || true
trap - EXIT

if [ "$VERSION_ID" -ge 9 ]; then
    protocol=HTTP/2
else
    protocol=HTTP/1.1
fi
echo "PASS: upgraded $BASE_VERSION -> $HOTFIX_VERSION with $nginx_binary_package ABI $abi_before, two fresh workers, proxying, mail, Lua, echo, stream and working $protocol"
