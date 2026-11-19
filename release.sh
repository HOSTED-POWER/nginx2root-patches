#!/bin/bash
# Create one complete package bundle per Debian release from a successful build.
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
OUT=$(realpath -m "${OUT:-$ROOT/out}")
DEST=$(realpath -m "${DEST:-$ROOT/release}")
VERSION=${VERSION:-v1.0.0}

mkdir -p "$DEST"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for release in 12 13; do
    source_dir="$OUT/debian$release"
    bundle="nginx2root-patches-$VERSION-debian$release-amd64"
    bundle_dir="$work/$bundle"
    mkdir -p "$bundle_dir/docs"
    cp "$source_dir"/*.deb "$bundle_dir/"
    cp "$ROOT/install.sh" "$ROOT/README.md" "$bundle_dir/"
    cp "$ROOT/docs/"*.png "$bundle_dir/docs/"
    (
        cd "$bundle_dir"
        sha256sum ./*.deb install.sh README.md docs/*.png > SHA256SUMS
    )
    tar --sort=name --owner=0 --group=0 --numeric-owner \
        --mtime='2026-11-19 00:00:00 UTC' \
        -C "$work" -cJf "$DEST/$bundle.tar.xz" "$bundle"
done

(
    cd "$DEST"
    sha256sum nginx2root-patches-"$VERSION"-debian*-amd64.tar.xz > SHA256SUMS
)

echo "Release bundles written to $DEST"
