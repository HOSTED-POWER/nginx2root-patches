#!/bin/bash
# test-rpm-package.sh <rpm-dir>   (run inside CentOS 7 container)
set -euo pipefail

RPM_DIR=$(realpath "$1")
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$HERE/configure-centos7-vault.sh"

. /etc/os-release
[ "$ID" = centos ] && [ "$VERSION_ID" = 7 ] || {
    echo 'test-rpm-package.sh requires CentOS 7' >&2
    exit 1
}

configure_centos7_vault
yum -q -y install nginx nginx-mod-mail nghttp2 >/dev/null

base_evr="$CENTOS7_EPEL_EPOCH:$CENTOS7_EPEL_VERSION-$CENTOS7_EPEL_BASE_RELEASE"
hotfix_evr="$CENTOS7_EPEL_EPOCH:$CENTOS7_EPEL_VERSION-$CENTOS7_EPEL_HOTFIX_RELEASE"
[ "$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' nginx)" = "$base_evr" ]

mapfile -t packages_before < <(rpm -qa --qf '%{NAME}\n' 'nginx*' | sort -u)
abi_before=$(rpm -q --provides nginx | awk '/^nginx\(abi\)/ { print; exit }')
[ -n "$abi_before" ]

cat > /etc/nginx/conf.d/nginx2root-http2-test.conf <<'EOF'
server {
    listen 127.0.0.1:8080 http2;
    location / {
        return 200 "nginx2root HTTP/2 test\n";
    }
}
EOF
nginx -t

"$ROOT/install-rpm.sh" "$RPM_DIR"

mapfile -t packages_after < <(rpm -qa --qf '%{NAME}\n' 'nginx*' | sort -u)
[ "${packages_before[*]}" = "${packages_after[*]}" ] || {
    echo 'installed NGINX package set changed during upgrade' >&2
    diff -u <(printf '%s\n' "${packages_before[@]}") <(printf '%s\n' "${packages_after[@]}") || true
    exit 1
}

for package_name in "${packages_after[@]}"; do
    [ "$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package_name")" = "$hotfix_evr" ] || {
        echo "$package_name was not upgraded to $hotfix_evr" >&2
        exit 1
    }
done

abi_after=$(rpm -q --provides nginx | awk '/^nginx\(abi\)/ { print; exit }')
[ "$abi_before" = "$abi_after" ] || {
    echo "NGINX ABI changed: $abi_before -> $abi_after" >&2
    exit 1
}

nginx -t
nginx
trap 'nginx -s quit >/dev/null 2>&1 || true' EXIT
sleep 1
http2_output=$(nghttp -nv http://127.0.0.1:8080/ 2>&1)
printf '%s\n' "$http2_output" | grep -Eq ':status: 200|:status: 200$'

echo "PASS: upgraded archived EPEL 7 NGINX packages to $hotfix_evr with ABI and HTTP/2 preserved"
