#!/bin/bash
# test-el9-rpm-package.sh <rpm-dir> <vendor:stream>
set -euo pipefail

RPM_DIR=$(realpath "$1")
TARGET=$2
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$HERE/security-changelog.sh"
el9_nginx_release_vars "$TARGET"
mapfile -t security_patches < <(el9_security_patches "$EL9_VERSION")

. /etc/os-release
[ "$ID" = "$EL9_OS_ID" ] && [ "${VERSION_ID%%.*}" = 9 ] || {
    echo "test-el9-rpm-package.sh requires $EL9_OS_ID 9" >&2
    exit 1
}

dnf -q -y install dnf-plugins-core >/dev/null
dnf -q -y module reset nginx >/dev/null
if [ "$EL9_STREAM" != base ]; then
    dnf -q -y module enable "nginx:$EL9_STREAM" >/dev/null
fi
command -v curl >/dev/null 2>&1
dnf -q -y install nginx nginx-mod-mail nginx-mod-stream >/dev/null

[ "$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' nginx)" = "$EL9_BASE_EVR" ]
mapfile -t packages_before < <(rpm -qa --qf '%{NAME}\n' 'nginx*' | sort -u)
abi_before=$(rpm -q --provides nginx | awk '/^nginx\(abi\)/ { print; exit }')

cat > /etc/nginx/conf.d/nginx2root-http2-test.conf <<'EOF'
server {
    listen 127.0.0.1:8080 http2;
    location / {
        return 200 "nginx2root EL9 HTTP/2 test\n";
    }
}
EOF
nginx -t

"$ROOT/install-el9-rpm.sh" "$RPM_DIR"

mapfile -t packages_after < <(rpm -qa --qf '%{NAME}\n' 'nginx*' | sort -u)
[ "${packages_before[*]}" = "${packages_after[*]}" ] || {
    echo 'installed NGINX package set changed during upgrade' >&2
    diff -u <(printf '%s\n' "${packages_before[@]}") <(printf '%s\n' "${packages_after[@]}") || true
    exit 1
}
for package_name in "${packages_after[@]}"; do
    [ "$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package_name")" = "$EL9_HOTFIX_EVR" ] || {
        echo "$package_name was not upgraded to $EL9_HOTFIX_EVR" >&2
        exit 1
    }
done

rpm_changelog=$(mktemp)
rpm -q --changelog nginx > "$rpm_changelog"
security_changelog_assert_cves "$rpm_changelog" "${security_patches[@]}"
[ "$(rpm -q --qf '%{BUILDTIME} %{BUILDHOST}' nginx)" = \
    '1795046400 packages.hosted-power.com' ]

abi_after=$(rpm -q --provides nginx | awk '/^nginx\(abi\)/ { print; exit }')
[ "$abi_before" = "$abi_after" ] || {
    echo "NGINX ABI changed: $abi_before -> $abi_after" >&2
    exit 1
}
package_modularity=$(rpm -q --qf '%{MODULARITYLABEL}' nginx)
if [ -n "$EL9_MODULARITY_LABEL" ]; then
    [ "$package_modularity" = "$EL9_MODULARITY_LABEL" ]
else
    [ "$package_modularity" = '(none)' ]
fi

nginx -t
nginx
trap 'nginx -s quit >/dev/null 2>&1 || true' EXIT
sleep 1
curl --http2-prior-knowledge -fsS http://127.0.0.1:8080/ |
    grep -q 'nginx2root EL9 HTTP/2 test'
nginx -s quit
wait || true
trap - EXIT

"$HERE/test-rpm-runtime.sh" "EL9 $TARGET $EL9_HOTFIX_EVR"
echo "PASS: upgraded EL9 $TARGET to $EL9_HOTFIX_EVR with package, module and runtime compatibility preserved"
