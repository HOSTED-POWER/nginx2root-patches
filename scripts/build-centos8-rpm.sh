#!/bin/bash
# build-centos8-rpm.sh <sources-dir> <out-dir> <stream>
set -euo pipefail

SRC=$(realpath "$1")
OUT=$(realpath -m "$2")
STREAM=$3
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$HERE/configure-centos8-vault.sh"
. "$HERE/patch-helpers.sh"
. "$HERE/security-changelog.sh"
centos8_nginx_release_vars "$STREAM"

. /etc/os-release
[ "$ID" = centos ] && [ "$VERSION_ID" = 8 ] || {
    echo 'build-centos8-rpm.sh requires CentOS Linux 8' >&2
    exit 1
}

configure_centos8_vault
dnf -q -y install ca-certificates cpio curl dnf-plugins-core gcc make \
    patch python3-rpm rpm-build rpmdevtools >/dev/null
"$HERE/test-centos8-rpm-version-order.sh"

TOP=/build/rpmbuild
[ ! -e "$TOP" ] || { echo "fixed RPM build path already exists: $TOP" >&2; exit 1; }
mkdir -p "$TOP" "$OUT"
rpm -ivh --define "_topdir $TOP" "$SRC/$CENTOS8_SOURCE_FILE" >/dev/null

spec="$TOP/SPECS/nginx.spec"
sed -i '/^Release:/ s/$/.0.1.hp3/' "$spec"
grep -q '^Release:.*\.0\.1\.hp3$' "$spec"

patch_files=()
if [ "$STREAM" = 1.14 ] || [ "$STREAM" = 1.16 ]; then
    prerequisite=mail-fixed-duplicate-resolving.patch
    cp "$ROOT/patches/prerequisites/$prerequisite" "$TOP/SOURCES/$prerequisite"
    patch_files+=("$prerequisite")
fi

mapfile -t security_patches < <(legacy_rpm_security_patches)

for patch_name in "${security_patches[@]}"; do
    cp "$ROOT/patches/$patch_name" "$TOP/SOURCES/$patch_name"
    if [ "$patch_name" = CVE-2026-123633.patch ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -3109,6 +3109,8 @@ ngx_http_v2_create_stream(ngx_http_v2_connection_t *h2c)'
    fi
    if [ "$patch_name" = CVE-2026-123640.patch ] && [ "$STREAM" = 1.14 ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -466,6 +503,14 @@ ngx_stream_ssl_preread_parse_record(ngx_stream_ssl_preread_ctx_t *ctx,'
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -475,7 +520,6 @@ ngx_stream_ssl_preread_parse_record(ngx_stream_ssl_preread_ctx_t *ctx,'
    fi
    if [ "$patch_name" = CVE-2026-123007.patch ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -203,14 +204,15 @@ static ngx_http_v2_handler_pt ngx_http_v2_frame_states[] = {'
        if [ "$STREAM" = 1.14 ] || [ "$STREAM" = 1.16 ]; then
            strip_patch_hunk "$TOP/SOURCES/$patch_name" \
                '@@ -1619,6 +1621,7 @@ done:'
        fi
    fi
    if [ "$patch_name" = CVE-2026-113425.patch ] && [ "$STREAM" != 1.20 ]; then
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -14,6 +14,7 @@'
        strip_patch_hunk "$TOP/SOURCES/$patch_name" \
            '@@ -165,6 +166,7 @@ ngx_mail_proxy_init(ngx_mail_session_t *s, ngx_addr_t *peer)'
    fi
    patch_files+=("$patch_name")
done

context_patch=CVE-2026-centos8-context.patch
if [ "$STREAM" != 1.20 ]; then
    cat > "$TOP/SOURCES/$context_patch" <<'EOF'
--- a/src/mail/ngx_mail_handler.c
+++ b/src/mail/ngx_mail_handler.c
@@ -12,6 +12,7 @@
 
 
 static void ngx_mail_init_session(ngx_connection_t *c);
+static void ngx_mail_block_read(ngx_event_t *rev);
 
 #if (NGX_MAIL_SSL)
 static void ngx_mail_ssl_init_connection(ngx_ssl_t *ssl, ngx_connection_t *c);
--- a/src/mail/ngx_mail_proxy_module.c
+++ b/src/mail/ngx_mail_proxy_module.c
@@ -147,6 +147,7 @@ ngx_mail_proxy_init(ngx_mail_session_t *s, ngx_addr_t *peer)
     p->upstream.connection->pool = s->connection->pool;
 
     s->connection->read->handler = ngx_mail_proxy_block_read;
+    s->connection->write->handler = ngx_mail_proxy_block_write;
     p->upstream.connection->write->handler = ngx_mail_proxy_dummy_handler;
 
     pcf = ngx_mail_get_module_srv_conf(s, ngx_mail_proxy_module);
EOF
fi

if [ "$STREAM" = 1.14 ] || [ "$STREAM" = 1.16 ]; then
    cat >> "$TOP/SOURCES/$context_patch" <<'EOF'
--- a/src/http/v2/ngx_http_v2_filter_module.c
+++ b/src/http/v2/ngx_http_v2_filter_module.c
@@ -2003,6 +2003,7 @@ done:
                    stream->node->id, frame);
 
     stream->request->header_size += NGX_HTTP_V2_FRAME_HEADER_SIZE;
+    ngx_http_v2_connection_private(h2c)->send_queued -= frame->length;
 
     ngx_http_v2_handle_frame(stream, frame);
 
EOF
fi
[ "$STREAM" = 1.20 ] || patch_files+=("$context_patch")

max_patch=$(sed -n 's/^Patch\([0-9][0-9]*\):.*/\1/p' "$spec" | sort -n | tail -1)
definitions=$(mktemp)
prep_block=$(mktemp)
patch_number=$((max_patch + 1))
for patch_name in "${patch_files[@]}"; do
    printf 'Patch%s:            %s\n' "$patch_number" "$patch_name" >> "$definitions"
    printf '%%patch%s -p1\n' "$patch_number" >> "$prep_block"
    patch_number=$((patch_number + 1))
done
cat >> "$prep_block" <<'EOF'
perl -0pi -e 's/(    ngx_http_v2_connection_t\s+\*h2c;\n)/$1    ngx_http_v2_connection_private_t  *h2p;\n/ or die "CentOS 8 HTTP\/2 declaration changed\n"' src/http/v2/ngx_http_v2.c
EOF
cat >> "$prep_block" <<'EOF'
perl -0pi -e 's/(    if \(push\) \{\n        h2c->pushing\+\+;\n\n    \} else \{\n        h2c->processing\+\+;\n    \}\n)/$1\n    ngx_reusable_connection(h2c->connection, 0);\n/ or die "CentOS 8 HTTP\/2 stream creation changed\n"' src/http/v2/ngx_http_v2.c
EOF

cp "$HERE/test-patches.sh" "$TOP/SOURCES/test-patches.sh"
printf 'Source211:         test-patches.sh\n' >> "$definitions"
reuse_required=1
smtp_read_guard_required=0
if [ "$STREAM" = 1.14 ] || [ "$STREAM" = 1.16 ]; then
    smtp_read_guard_required=1
fi
ssl_preread_required=2
[ "$STREAM" = 1.14 ] && ssl_preread_required=1
printf '\n%%check\n%%{SOURCE211} . 11 %s %s 1 1 %s 0 0 0\n\n' \
    "$reuse_required" "$smtp_read_guard_required" "$ssl_preread_required" \
    >> "$prep_block"

awk -v insert="$definitions" '
    !done && /^%description/ {
        while ((getline line < insert) > 0) print line
        close(insert)
        done=1
    }
    { print }
' "$spec" > "$spec.new"
mv "$spec.new" "$spec"
awk -v insert="$prep_block" '
    !done && /^%build/ {
        while ((getline line < insert) > 0) print line
        close(insert)
        done=1
    }
    { print }
' "$spec" > "$spec.new"
mv "$spec.new" "$spec"

changelog_entry=$(mktemp)
{
    printf '* Wed Nov 18 2026 Hosted Power <packages@hosted-power.com> - 1:%s-%s\n' \
        "$CENTOS8_VERSION" "$CENTOS8_HOTFIX_RELEASE"
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

dnf -q -y builddep "$SRC/$CENTOS8_SOURCE_FILE" >/dev/null
useradd --system --no-create-home builder
chown -R builder "$TOP" "$OUT"
su -s /bin/bash builder -c \
    "HOME=/build SOURCE_DATE_EPOCH=1795046400 rpmbuild --define '_topdir $TOP' --define '_buildhost packages.hosted-power.com' --define 'use_source_date_epoch_as_buildtime 1' --define 'clamp_mtime_to_source_date_epoch 1' --define 'dist $CENTOS8_DIST' --define 'modularitylabel $CENTOS8_MODULARITY_LABEL' -bb '$spec'" \
    > "$OUT/build-centos8-$STREAM.log" 2>&1 || {
        tail -120 "$OUT/build-centos8-$STREAM.log"
        exit 1
    }

find "$TOP/RPMS" -type f -name '*.rpm' ! -name '*-debuginfo-*' ! -name '*-debugsource-*' \
    -exec mv -t "$OUT" {} +
expected_evr="$CENTOS8_EPOCH:$CENTOS8_VERSION-$CENTOS8_HOTFIX_RELEASE"
for package in "$OUT"/*.rpm; do
    [ "$(rpm -qp --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package")" = "$expected_evr" ] || {
        echo "unexpected package version: $package" >&2
        exit 1
    }
    [ "$(rpm -qp --qf '%{MODULARITYLABEL}' "$package")" = "$CENTOS8_MODULARITY_LABEL" ] || {
        echo "unexpected modularity label: $package" >&2
        exit 1
    }
done

echo "built CentOS 8 NGINX $STREAM hotfix $expected_evr:"
ls "$OUT"/*.rpm
