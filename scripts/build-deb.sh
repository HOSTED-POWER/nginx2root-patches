#!/bin/bash
# build-deb.sh <sources-dir> <out-dir>   (run inside matching Debian container)
set -euo pipefail
SRC=$(realpath "$1")
OUT=$(realpath -m "$2")
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. "$ROOT/scripts/configure-legacy-apt.sh"
. "$ROOT/scripts/patch-helpers.sh"
. /etc/os-release
nginx_release_vars "$VERSION_ID"
export DEBIAN_FRONTEND=noninteractive

configure_legacy_apt "$VERSION_ID" "$RELEASE_CODENAME"
apt-get update -qq
apt-get install -y -qq --no-install-recommends \
    build-essential ca-certificates devscripts equivs quilt xz-utils >/dev/null

WORK=/build/nginx-hotfix
[ ! -e "$WORK" ] || { echo "fixed build path already exists: $WORK" >&2; exit 1; }
SOURCE="$WORK/nginx"
PATCH_SOURCE="$ROOT/patches"
mkdir -p "$SOURCE" "$OUT"
tar -xzf "$SRC/$ORIG_FILE" -C "$SOURCE" --strip-components=1
tar -xJf "$SRC/$DEBIAN_FILE" -C "$SOURCE"

cd "$SOURCE"
export QUILT_PATCHES=debian/patches
quilt push -a -q

if [ "$VERSION_ID" -le 10 ]; then
    prerequisite=mail-fixed-duplicate-resolving.patch
    cp "$PATCH_SOURCE/prerequisites/$prerequisite" "debian/patches/$prerequisite"
    printf '%s\n' "$prerequisite" >> debian/patches/series
    quilt push -q
    quilt refresh -p ab --no-timestamps --no-index
fi

patches=(CVE-2026-123634.patch CVE-2026-113425.patch)
if [ "$VERSION_ID" -ge 9 ]; then
    patches=(
        CVE-2026-123633.patch
        CVE-2026-123634.patch
        CVE-2026-123007.patch
        CVE-2026-113425.patch
    )
fi
[ "$VERSION_ID" = 13 ] && patches+=(CVE-2026-121810.patch)

for patch in "${patches[@]}"; do
    source_patch="$PATCH_SOURCE/$patch"
    [ -f "$source_patch" ] || { echo "missing Debian security patch: $patch" >&2; exit 1; }
    cp "$source_patch" "debian/patches/$patch"
    if [ "$VERSION_ID" = 8 ] && [ "$patch" = CVE-2026-123634.patch ]; then
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -570,9 +571,11 @@ ngx_resolve_name_done(ngx_resolver_ctx_t *ctx)'
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -2935,7 +2963,22 @@ ngx_resolver_process_srv(ngx_resolver_t *r, u_char *buf, size_t n,'
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -2975,6 +3018,11 @@ ngx_resolver_resolve_srv_names(ngx_resolver_ctx_t *ctx, ngx_resolver_node_t *rn)'
    fi
    if [ "$VERSION_ID" -le 12 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -203,14 +204,15 @@ static ngx_http_v2_handler_pt ngx_http_v2_frame_states[] = {'
    fi
    if [ "$VERSION_ID" = 9 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -1224,6 +1225,7 @@ ngx_http_v2_send_chain(ngx_connection_t *fc, ngx_chain_t *in, off_t limit)'
    fi
    if [ "$VERSION_ID" -le 10 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -1619,6 +1621,7 @@ done:'
    fi
    if [ "$VERSION_ID" -le 11 ] && [ "$patch" = CVE-2026-113425.patch ]; then
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -165,6 +166,7 @@ ngx_mail_proxy_init(ngx_mail_session_t *s, ngx_addr_t *peer)'
    fi
    if [ "$VERSION_ID" = 8 ] && [ "$patch" = CVE-2026-113425.patch ]; then
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -415,8 +416,6 @@ ngx_mail_verify_cert(ngx_mail_session_t *s, ngx_connection_t *c)'
        strip_patch_hunk "debian/patches/$patch" \
            '@@ -436,8 +435,6 @@ ngx_mail_verify_cert(ngx_mail_session_t *s, ngx_connection_t *c)'
    fi
    printf '%s\n' "$patch" >> debian/patches/series
    quilt push -q
    if [ "$VERSION_ID" = 8 ] && [ "$patch" = CVE-2026-123634.patch ]; then
        perl -0pi -e '
            s/        ngx_log_error\(NGX_LOG_ALERT, r->log, 0,\n                      "could not cancel %V resolving", &ctx->name\);\n    }/        ngx_log_debug1(NGX_LOG_DEBUG_CORE, r->log, 0,\n                       "could not cancel %V resolving", &ctx->name);\n\n        ctx->handler = ngx_resolver_free_handler;\n    }/
                or die "Jessie resolver cancellation block changed\n";
            s/                    ctx->valid = ngx_time\(\) \+ \(r->valid \? r->valid : 10\);\n//
                or die "Jessie resolver error validity line changed\n";
        ' src/core/ngx_resolver.c
    fi
    if [ "$VERSION_ID" -le 12 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        perl -0pi -e '
            s/(ngx_http_v2_main_conf_t   \*h2mcf;\n    ngx_http_v2_connection_t  \*h2c;\n)/$1    ngx_http_v2_connection_private_t  *h2p;\n/
                or die "legacy HTTP\/2 connection declaration changed\n";
        ' src/http/v2/ngx_http_v2.c
    fi
    if [ "$VERSION_ID" = 9 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        perl -0pi -e '
            s/^([ \t]*)h2c->send_window -= frame_size;\n/$1h2c->send_window -= frame_size;\n$1ngx_http_v2_connection_private(h2c)->send_queued += frame_size;\n/m
                or die "Stretch HTTP\/2 queue insertion point changed\n";
        ' src/http/v2/ngx_http_v2_filter_module.c
    fi
    if [ "$VERSION_ID" -le 10 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        perl -0pi -e '
            s/(    stream->request->header_size \+= NGX_HTTP_V2_FRAME_HEADER_SIZE;\n\n)(    ngx_http_v2_handle_frame\(stream, frame\);)/$1    ngx_http_v2_connection_private(h2c)->send_queued -= frame->length;\n\n$2/
                or die "legacy HTTP\/2 completion insertion point changed\n";
        ' src/http/v2/ngx_http_v2_filter_module.c
    fi
    if [ "$VERSION_ID" -le 11 ] && [ "$patch" = CVE-2026-113425.patch ]; then
        perl -0pi -e '
            s/(    s->connection->read->handler = ngx_mail_proxy_block_read;\n)/$1    s->connection->write->handler = ngx_mail_proxy_block_write;\n/
                or die "legacy mail proxy handler insertion point changed\n";
        ' src/mail/ngx_mail_proxy_module.c
    fi
    quilt refresh -p ab --no-timestamps --no-index
done

"$HERE/test-patches.sh" "$SOURCE" "$VERSION_ID"

DEBEMAIL='packages@hosted-power.com' DEBFULLNAME='Hosted Power' \
    dch --newversion "$HOTFIX_VERSION" --distribution "$RELEASE_CODENAME" --force-distribution \
    'Backport Debian fixes for the November 2026 NGINX security vulnerabilities.' >/dev/null 2>&1
sed -i '0,/^ -- Hosted Power <packages@hosted-power.com>  /s#^ -- Hosted Power <packages@hosted-power.com>  .*# -- Hosted Power <packages@hosted-power.com>  Wed, 18 Nov 2026 00:00:00 +0000#' \
    debian/changelog
grep -qF ' -- Hosted Power <packages@hosted-power.com>  Wed, 18 Nov 2026 00:00:00 +0000' \
    debian/changelog

mk-build-deps -i -r -t 'apt-get -y -qq --no-install-recommends' debian/control >/dev/null
id builder >/dev/null 2>&1 || useradd --system --no-create-home builder
chown -R builder "$WORK" "$OUT"
runuser -u builder -- env HOME="$WORK" dpkg-buildpackage -b -us -uc \
    > "$OUT/build-debian${VERSION_ID}.log" 2>&1 || {
        tail -100 "$OUT/build-debian${VERSION_ID}.log"
        exit 1
    }
mv "$WORK"/*.deb "$OUT/"
rm -f "$OUT"/*-dbgsym_*.deb

for package in "$OUT"/*.deb; do
    [ "$(dpkg-deb -f "$package" Version)" = "$HOTFIX_VERSION" ] \
        || { echo "unexpected package version: $package" >&2; exit 1; }
done
echo "built $HOTFIX_VERSION:"
ls "$OUT"/*.deb
