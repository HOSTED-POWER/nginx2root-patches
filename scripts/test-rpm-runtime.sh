#!/bin/bash
set -euo pipefail

LABEL=$1
SMOKE=$(mktemp -d)
mkdir -p "$SMOKE/html" "$SMOKE/logs"
chmod 0755 "$SMOKE" "$SMOKE/html"
printf 'nginx hotfix backend response\n' > "$SMOKE/html/index.html"

cat > "$SMOKE/nginx.conf" <<EOF
include /usr/share/nginx/modules/*.conf;
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
    }
    server {
        listen 127.0.0.1:18082 http2;
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
stream {
    server {
        listen 127.0.0.1:18083;
        proxy_pass 127.0.0.1:18081;
    }
}
EOF

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

if command -v nghttp >/dev/null 2>&1; then
    nghttp http://127.0.0.1:18082/ 2>&1 |
        grep -q 'nginx hotfix HTTP/2 response'
else
    curl --http2-prior-knowledge -fsS http://127.0.0.1:18082/ |
        grep -q 'nginx hotfix HTTP/2 response'
fi
curl -fsS http://127.0.0.1:18083/ | grep -q 'nginx hotfix backend response'
smtp_greeting=$(
    exec 3<>/dev/tcp/127.0.0.1/18025
    IFS= read -r line <&3
    printf '%s\n' "$line"
)
printf '%s\n' "$smtp_greeting" | grep -q '^220 '

kill "$nginx_pid"
wait "$nginx_pid" || true
trap - EXIT
echo "PASS: $LABEL serves HTTP/1.1, HTTP/2, proxy, stream and mail with two fresh workers"
