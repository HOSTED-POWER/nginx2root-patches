#!/bin/bash
# build-el9-rpm.sh <sources-dir> <out-dir> <vendor:stream>
set -euo pipefail

SRC=$(realpath "$1")
OUT=$(realpath -m "$2")
TARGET=$3
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$HERE/patch-helpers.sh"
. "$HERE/security-changelog.sh"
el9_nginx_release_vars "$TARGET"

. /etc/os-release
[ "$ID" = "$EL9_OS_ID" ] && [ "${VERSION_ID%%.*}" = "$EL9_MAJOR" ] || {
    echo "build-el9-rpm.sh requires $EL9_OS_ID $EL9_MAJOR" >&2
    exit 1
}

dnf -q -y install ca-certificates cpio dnf-plugins-core gcc make patch \
    python3-rpm rpm-build rpmdevtools >/dev/null

TOP=/build/rpmbuild
[ ! -e "$TOP" ] || { echo "fixed RPM build path already exists: $TOP" >&2; exit 1; }
mkdir -p "$TOP" "$OUT"
rpm -ivh --define "_topdir $TOP" "$SRC/$EL9_SOURCE_FILE" >/dev/null

spec="$TOP/SPECS/nginx.spec"
sed -i "s/^Release:.*/Release:           $EL9_HOTFIX_RELEASE/" "$spec"
grep -qF "Release:           $EL9_HOTFIX_RELEASE" "$spec"
grep -Eq '^%autosetup .* -p1|^%autosetup -p1' "$spec" || {
    echo 'unsupported NGINX spec: expected %autosetup -p1' >&2
    exit 1
}
if grep -q '^%check' "$spec"; then
    echo 'unsupported NGINX spec: an existing %check section needs explicit integration' >&2
    exit 1
fi

mapfile -t security_patches < <(el9_security_patches "$EL9_VERSION")
patch_files=("${security_patches[@]}")
for patch_name in "${security_patches[@]}"; do
    cp "$ROOT/patches/$patch_name" "$TOP/SOURCES/$patch_name"
    if [ "$patch_name" = CVE-2026-123007.patch ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -8,6 +8,7 @@'
    fi
    if [ "$EL9_VERSION" != 1.26.3 ] && [ "$patch_name" = CVE-2026-123633.patch ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -3109,6 +3109,8 @@ ngx_http_v2_create_stream(ngx_http_v2_connection_t *h2c)'
    fi
    if [ "$EL9_VERSION" != 1.26.3 ] && [ "$patch_name" = CVE-2026-123007.patch ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -203,14 +204,15 @@ static ngx_http_v2_handler_pt ngx_http_v2_frame_states[] = {'
    fi
done

max_patch=$(sed -n 's/^Patch\([0-9][0-9]*\):.*/\1/p' "$spec" | sort -n | tail -1)
definitions=$(mktemp)
patch_number=$((max_patch + 1))
for patch_name in "${patch_files[@]}"; do
    printf 'Patch%s:            %s\n' "$patch_number" "$patch_name" >> "$definitions"
    patch_number=$((patch_number + 1))
done

cp "$HERE/test-patches.sh" "$TOP/SOURCES/test-patches.sh"
printf 'Source211:         test-patches.sh\n' >> "$definitions"
awk -v insert="$definitions" '
    !done && /^%description/ {
        while ((getline line < insert) > 0) print line
        close(insert)
        done=1
    }
    { print }
' "$spec" > "$spec.new"
mv "$spec.new" "$spec"
rm -f "$definitions"

prep_checks=$(mktemp)
cat >> "$prep_checks" <<'EOF'
perl -0pi -e 'die "EL9 HTTP\/2 private include already exists\n" if /#include <ngx_http_v2_connection\.hh>/; s/(#include <ngx_http\.h>\n)/$1#include <ngx_http_v2_connection.hh>\n/ or die "EL9 HTTP\/2 include context changed\n"' src/http/v2/ngx_http_v2.c
EOF
if [ "$EL9_VERSION" != 1.26.3 ]; then
    cat >> "$prep_checks" <<'EOF'
perl -0pi -e 's/(    ngx_http_v2_connection_t\s+\*h2c;\n)/$1    ngx_http_v2_connection_private_t  *h2p;\n/ or die "EL9 HTTP\/2 declaration changed\n"' src/http/v2/ngx_http_v2.c
perl -0pi -e 's/(    if \(push\) \{\n        h2c->pushing\+\+;\n\n    \} else \{\n        h2c->processing\+\+;\n    \}\n)/$1\n    ngx_reusable_connection(h2c->connection, 0);\n/ or die "EL9 HTTP\/2 stream creation changed\n"' src/http/v2/ngx_http_v2.c
EOF
fi

source_release=14
stream_sni_verify_required=0
if [ "$EL9_VERSION" = 1.26.3 ]; then
    source_release=13
    stream_sni_verify_required=1
fi
printf '\n%%check\n%%{SOURCE211} . %s 1 0 1 1 2 %s 0 0\n\n' \
    "$source_release" "$stream_sni_verify_required" >> "$prep_checks"
awk -v insert="$prep_checks" '
    !done && /^%build/ {
        while ((getline line < insert) > 0) print line
        close(insert)
        done=1
    }
    { print }
' "$spec" > "$spec.new"
mv "$spec.new" "$spec"
rm -f "$prep_checks"

changelog_entry=$(mktemp)
{
    printf '* Thu Nov 19 2026 Hosted Power <packages@hosted-power.com> - %s:%s-%s\n' \
        "$EL9_EPOCH" "$EL9_VERSION" "$EL9_HOTFIX_RELEASE"
    security_changelog_lines rpm "${security_patches[@]}"
    printf '\n'
} > "$changelog_entry"
awk -v insert="$changelog_entry" '
    { print }
    !done && /^%changelog$/ {
        while ((getline line < insert) > 0) print line
        close(insert)
        done=1
    }
' "$spec" > "$spec.new"
mv "$spec.new" "$spec"
rm -f "$changelog_entry"
security_changelog_assert_cves "$spec" "${security_patches[@]}"

dnf -q -y builddep "$SRC/$EL9_SOURCE_FILE" >/dev/null
useradd --system --no-create-home builder
chown -R builder "$TOP" "$OUT"
modularity_option=()
if [ -n "$EL9_MODULARITY_LABEL" ]; then
    modularity_option=(--define "modularitylabel $EL9_MODULARITY_LABEL")
fi
runuser -u builder -- env HOME=/build SOURCE_DATE_EPOCH=1795046400 \
    rpmbuild --define "_topdir $TOP" \
    --define '_buildhost packages.hosted-power.com' \
    --define 'use_source_date_epoch_as_buildtime 1' \
    --define 'clamp_mtime_to_source_date_epoch 1' \
    "${modularity_option[@]}" -bb "$spec" \
    > "$OUT/build-$EL9_VENDOR-$EL9_STREAM.log" 2>&1 || {
        find "$TOP/BUILD" -type f -name '*.rej' -exec cp -t "$OUT" {} + 2>/dev/null || true
        tail -120 "$OUT/build-$EL9_VENDOR-$EL9_STREAM.log"
        exit 1
    }

find "$TOP/RPMS" -type f -name '*.rpm' ! -name '*-debuginfo-*' ! -name '*-debugsource-*' \
    -exec mv -t "$OUT" {} +
for package in "$OUT"/*.rpm; do
    [ "$(rpm -qp --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package")" = "$EL9_HOTFIX_EVR" ] || {
        echo "unexpected package version: $package" >&2
        exit 1
    }
    package_modularity=$(rpm -qp --qf '%{MODULARITYLABEL}' "$package")
    if [ -n "$EL9_MODULARITY_LABEL" ]; then
        [ "$package_modularity" = "$EL9_MODULARITY_LABEL" ] || {
            echo "unexpected modularity label: $package" >&2
            exit 1
        }
    else
        [ "$package_modularity" = '(none)' ] || {
            echo "unexpected modularity label on non-modular package: $package" >&2
            exit 1
        }
    fi
done

case "$EL9_VENDOR" in
    rhel) target_name='Red Hat Enterprise Linux' ;;
    almalinux) target_name='AlmaLinux' ;;
    rockylinux) target_name='Rocky Linux' ;;
    oraclelinux) target_name='Oracle Linux' ;;
esac
{
    printf 'TARGET_NAME=%q\n' "$target_name"
    printf 'TARGET_VENDOR=%q\n' "$EL9_VENDOR"
    printf 'TARGET_OS_ID=%q\n' "$EL9_OS_ID"
    printf 'TARGET_MAJOR=%q\n' "$EL9_MAJOR"
    printf 'TARGET_STREAM=%q\n' "$EL9_STREAM"
    printf 'BASE_EVR=%q\n' "$EL9_BASE_EVR"
    printf 'HOTFIX_EVR=%q\n' "$EL9_HOTFIX_EVR"
    printf 'MODULARITY_LABEL=%q\n' "$EL9_MODULARITY_LABEL"
} > "$OUT/bundle.env"

echo "built $TARGET NGINX hotfix $EL9_HOTFIX_EVR"
ls "$OUT"/*.rpm
