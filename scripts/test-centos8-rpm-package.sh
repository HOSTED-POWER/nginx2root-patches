#!/bin/bash
# test-centos8-rpm-package.sh <rpm-dir> <stream>
set -euo pipefail

RPM_DIR=$(realpath "$1")
STREAM=$2
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$HERE/configure-centos8-vault.sh"
centos8_nginx_release_vars "$STREAM"

. /etc/os-release
[ "$ID" = centos ] && [ "$VERSION_ID" = 8 ] || {
    echo 'test-centos8-rpm-package.sh requires CentOS Linux 8' >&2
    exit 1
}

configure_centos8_vault
dnf -q -y module enable "nginx:$STREAM" >/dev/null
dnf -q -y install nginx nginx-mod-mail nghttp2 >/dev/null

base_evr="$CENTOS8_EPOCH:$CENTOS8_VERSION-$CENTOS8_BASE_RELEASE"
hotfix_evr="$CENTOS8_EPOCH:$CENTOS8_VERSION-$CENTOS8_HOTFIX_RELEASE"
[ "$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' nginx)" = "$base_evr" ]

mapfile -t packages_before < <(rpm -qa --qf '%{NAME}\n' 'nginx*' | sort -u)
abi_before=$(rpm -q --provides nginx | awk '/^nginx\(abi\)/ { print; exit }')

cat > /etc/nginx/conf.d/nginx2root-http2-test.conf <<'EOF'
server {
    listen 127.0.0.1:8080 http2;
    location / {
        return 200 "nginx2root CentOS 8 HTTP/2 test\n";
    }
}
EOF
nginx -t

"$ROOT/install-centos8-rpm.sh" "$RPM_DIR"

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

[ "$(rpm -q --qf '%{MODULARITYLABEL}' nginx)" = "$CENTOS8_MODULARITY_LABEL" ]
nginx -t
nginx
trap 'nginx -s quit >/dev/null 2>&1 || true' EXIT
sleep 1
http2_output=$(nghttp -nv http://127.0.0.1:8080/ 2>&1)
printf '%s\n' "$http2_output" | grep -Eq ':status: 200|:status: 200$'

echo "PASS: upgraded CentOS 8 NGINX $STREAM to $hotfix_evr with module identity, package compatibility and HTTP/2 preserved"
