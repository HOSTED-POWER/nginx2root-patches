#!/bin/bash
# Create one complete package bundle per supported distribution from a successful build.
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
OUT=$(realpath -m "${OUT:-$ROOT/out}")
DEST=$(realpath -m "${DEST:-$ROOT/release}")
VERSION=${VERSION:-v1.3.0}

mkdir -p "$DEST"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for release in 8 9 10 11 12 13; do
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

source_dir="$OUT/centos7"
bundle="nginx2root-patches-$VERSION-centos7-epel-x86_64"
bundle_dir="$work/$bundle"
mkdir -p "$bundle_dir/docs"
cp "$source_dir"/*.rpm "$bundle_dir/"
cp "$ROOT/install-rpm.sh" "$ROOT/README.md" "$bundle_dir/"
cp "$ROOT/docs/"*.png "$bundle_dir/docs/"
(
    cd "$bundle_dir"
    sha256sum ./*.rpm install-rpm.sh README.md docs/*.png > SHA256SUMS
)
tar --sort=name --owner=0 --group=0 --numeric-owner \
    --mtime='2026-11-19 00:00:00 UTC' \
    -C "$work" -cJf "$DEST/$bundle.tar.xz" "$bundle"

for stream in 1.14 1.16 1.18 1.20; do
    source_dir="$OUT/centos8/$stream"
    bundle="nginx2root-patches-$VERSION-centos8-appstream-$stream-x86_64"
    bundle_dir="$work/$bundle"
    mkdir -p "$bundle_dir/docs"
    cp "$source_dir"/*.rpm "$bundle_dir/"
    cp "$ROOT/install-centos8-rpm.sh" "$ROOT/README.md" "$bundle_dir/"
    cp "$ROOT/docs/"*.png "$bundle_dir/docs/"
    (
        cd "$bundle_dir"
        sha256sum ./*.rpm install-centos8-rpm.sh README.md docs/*.png > SHA256SUMS
    )
    tar --sort=name --owner=0 --group=0 --numeric-owner \
        --mtime='2026-11-19 00:00:00 UTC' \
        -C "$work" -cJf "$DEST/$bundle.tar.xz" "$bundle"
done

(
    cd "$DEST"
    sha256sum nginx2root-patches-"$VERSION"-*.tar.xz > SHA256SUMS
)

echo "Release bundles written to $DEST"
