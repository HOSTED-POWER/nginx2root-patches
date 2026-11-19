#!/bin/bash
# build-deb.sh <sources-dir> <out-dir>   (run inside debian:12/13)
set -euo pipefail
SRC=$(realpath "$1")
OUT=$(realpath -m "$2")
HERE=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$HERE")
. "$ROOT/versions.sh"
. /etc/os-release
nginx_release_vars "$VERSION_ID"
export DEBIAN_FRONTEND=noninteractive

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

patches=(
    CVE-2026-123633.patch
    CVE-2026-123634.patch
    CVE-2026-123007.patch
    CVE-2026-113425.patch
)
[ "$VERSION_ID" = 13 ] && patches+=(CVE-2026-121810.patch)

for patch in "${patches[@]}"; do
    source_patch="$PATCH_SOURCE/$patch"
    [ -f "$source_patch" ] || { echo "missing Debian security patch: $patch" >&2; exit 1; }
    cp "$source_patch" "debian/patches/$patch"
    if [ "$VERSION_ID" = 12 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        grep -qF '@@ -203,14 +204,15 @@ static ngx_http_v2_handler_pt ngx_http_v2_frame_states[] = {' \
            "debian/patches/$patch" || {
                echo "Bookworm HTTP/2 declaration context changed" >&2
                exit 1
            }
        awk '
            /^@@ -203,14 \+204,15 @@ static ngx_http_v2_handler_pt ngx_http_v2_frame_states\[\] = \{/ { skip=1; next }
            skip && /^@@ / { skip=0 }
            !skip { print }
        ' "debian/patches/$patch" > "debian/patches/$patch.tmp"
        mv "debian/patches/$patch.tmp" "debian/patches/$patch"
    fi
    printf '%s\n' "$patch" >> debian/patches/series
    quilt push -q
    if [ "$VERSION_ID" = 12 ] && [ "$patch" = CVE-2026-123007.patch ]; then
        perl -0pi -e '
            s/(ngx_http_v2_main_conf_t   \*h2mcf;\n    ngx_http_v2_connection_t  \*h2c;\n)/$1    ngx_http_v2_connection_private_t  *h2p;\n/
                or die "Bookworm HTTP\/2 connection declaration changed\n";
        ' src/http/v2/ngx_http_v2.c
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
