#!/bin/bash
# build-rpm.sh <sources-dir> <out-dir>   (run inside CentOS 7 container)
set -euo pipefail
SRC=$(realpath "$1")
OUT=$(realpath -m "$2")
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$ROOT/scripts/configure-centos7-vault.sh"
. "$ROOT/scripts/patch-helpers.sh"

. /etc/os-release
[ "$ID" = centos ] && [ "$VERSION_ID" = 7 ] || {
    echo 'build-rpm.sh requires CentOS 7' >&2
    exit 1
}

configure_centos7_vault
yum -q -y install ca-certificates cpio curl epel-rpm-macros rpm-build \
    rpm-python rpmdevtools yum-utils >/dev/null
"$HERE/test-rpm-version-order.sh"

TOP=/build/rpmbuild
[ ! -e "$TOP" ] || { echo "fixed RPM build path already exists: $TOP" >&2; exit 1; }
mkdir -p "$TOP" "$OUT"
rpm -ivh --define "_topdir $TOP" "$SRC/$CENTOS7_EPEL_SOURCE_FILE" >/dev/null

spec="$TOP/SPECS/nginx.spec"
sed -i 's/^Release:[[:space:]]*10%{?dist}$/Release:           10%{?dist}.0.1.hp2/' "$spec"
grep -q '^Release:[[:space:]]*10%{?dist}.0.1.hp2$' "$spec"

patches=(
    CVE-2026-123633.patch
    CVE-2026-123640.patch
    CVE-2026-118899-legacy.patch
    CVE-2026-123634.patch
    CVE-2026-123007.patch
    CVE-2026-113425.patch
    CVE-2026-125283-legacy-module.patch
)
patch_number=4
for patch in "${patches[@]}"; do
    cp "$ROOT/patches/$patch" "$TOP/SOURCES/$patch"
    if [ "$patch" = CVE-2026-123007.patch ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch" \
            '@@ -203,14 +204,15 @@ static ngx_http_v2_handler_pt ngx_http_v2_frame_states[] = {'
    fi
    sed -i "/^Patch3:/a Patch${patch_number}:            $patch" "$spec"
    patch_number=$((patch_number + 1))
done

cat > "$TOP/SOURCES/CVE-2026-123007-epel7-context.patch" <<'EOF'
--- a/src/http/v2/ngx_http_v2.c
+++ b/src/http/v2/ngx_http_v2.c
@@ -237,6 +237,7 @@ ngx_http_v2_init(ngx_event_t *rev)
     ngx_http_v2_srv_conf_t    *h2scf;
     ngx_http_v2_main_conf_t   *h2mcf;
     ngx_http_v2_connection_t  *h2c;
+    ngx_http_v2_connection_private_t  *h2p;
     ngx_http_core_srv_conf_t  *cscf;

     c = rev->data;
EOF
context_patch_number=$patch_number
sed -i "/^Patch$((patch_number - 1)):/a Patch${context_patch_number}:            CVE-2026-123007-epel7-context.patch" "$spec"
cp "$ROOT/scripts/test-patches.sh" "$TOP/SOURCES/test-patches.sh"
cp "$ROOT/scripts/gpgverify-rpm.sh" "$TOP/SOURCES/gpgverify-rpm.sh"
chmod 0755 "$TOP/SOURCES/gpgverify-rpm.sh"
sed -i '/^Source210:/a Source211:         test-patches.sh' "$spec"
sed -i '/^%build$/i %check\n%{SOURCE211} . 11 1 0 1 1 2 0 0 0\n' "$spec"
sed -i '/^%changelog$/a * Thu Nov 19 2026 Hosted Power <packages@hosted-power.com> - 1:1.20.1-10.el7.0.1.hp2\n- Complete backports for the November 2026 NGINX security vulnerabilities.\n' "$spec"

yum-builddep -q -y "$SRC/$CENTOS7_EPEL_SOURCE_FILE" >/dev/null
useradd --system --no-create-home builder
chown -R builder "$TOP" "$OUT"
su -s /bin/bash builder -c \
    "HOME=/build rpmbuild --define '_topdir $TOP' --define 'gpgverify $TOP/SOURCES/gpgverify-rpm.sh' -bb '$spec'" \
    > "$OUT/build-centos7.log" 2>&1 || {
        tail -100 "$OUT/build-centos7.log"
        exit 1
    }

find "$TOP/RPMS" -type f -name '*.rpm' ! -name '*-debuginfo-*' \
    -exec mv -t "$OUT" {} +
for package in "$OUT"/*.rpm; do
    [ "$(rpm -qp --qf '%{EPOCH}:%{VERSION}-%{RELEASE}' "$package")" = \
        "$CENTOS7_EPEL_EPOCH:$CENTOS7_EPEL_VERSION-$CENTOS7_EPEL_HOTFIX_RELEASE" ] || {
        echo "unexpected package version: $package" >&2
        exit 1
    }
done

echo "built EPEL 7 hotfix $CENTOS7_EPEL_EPOCH:$CENTOS7_EPEL_VERSION-$CENTOS7_EPEL_HOTFIX_RELEASE:"
ls "$OUT"/*.rpm
