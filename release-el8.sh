#!/bin/bash
# Create deterministic native Enterprise Linux 8 release bundles.
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
OUT=$(realpath -m "${OUT:-$ROOT/out}")
DEST=$(realpath -m "${DEST:-$ROOT/release}")
VERSION=${VERSION:-v1.6.1}

. "$ROOT/versions.sh"
mkdir -p "$DEST"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

while IFS= read -r target; do
    el9_nginx_release_vars "$target"
    source_dir="$OUT/el8/$EL9_VENDOR/$EL9_STREAM"
    bundle="nginx2root-patches-$VERSION-$EL9_VENDOR-el8-$EL9_STREAM-x86_64"
    bundle_dir="$work/$bundle"
    mkdir -p "$bundle_dir/docs"
    cp "$source_dir"/*.rpm "$source_dir/bundle.env" "$bundle_dir/"
    cp "$ROOT/install-el8-rpm.sh" "$ROOT/install-el9-rpm.sh" \
        "$ROOT/README.md" "$bundle_dir/"
    cp "$ROOT/docs/"*.png "$bundle_dir/docs/"
    (
        cd "$bundle_dir"
        sha256sum ./*.rpm bundle.env install-el8-rpm.sh install-el9-rpm.sh \
            README.md docs/*.png > SHA256SUMS
    )
    tar --sort=name --owner=0 --group=0 --numeric-owner \
        --mtime='2026-11-19 00:00:00 UTC' \
        -C "$work" -cJf "$DEST/$bundle.tar.xz" "$bundle"
done < <(el8_targets)

(
    cd "$DEST"
    sha256sum nginx2root-patches-"$VERSION"-*-el8-*.tar.xz > \
        "SHA256SUMS-$VERSION-el8"
)
echo "EL8 release bundles written to $DEST"
