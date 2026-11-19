#!/bin/bash
set -euo pipefail

ROOT=$(dirname "$(dirname "$(realpath "$0")")")
. "$ROOT/versions.sh"

mapfile -t targets < <(el10_targets)
[ "${targets[*]}" = 'rhel10:base rockylinux10:base oraclelinux10:base' ]

assert_target() {
    local target=$1 vendor=$2 os_id=$3 image=$4
    local image_tag=$5 base_release=$6 source_file=$7 source_sha256=$8
    local source_url=$9

    el9_nginx_release_vars "$target"
    [ "$EL9_VENDOR" = "$vendor" ]
    [ "$EL9_STREAM" = base ]
    [ "$EL9_MAJOR" = 10 ]
    [ "$EL9_OS_ID" = "$os_id" ]
    [ "$EL9_IMAGE" = "$image" ]
    [ "$EL9_IMAGE_TAG" = "$image_tag" ]
    [ "$EL9_EPOCH" = 2 ]
    [ "$EL9_VERSION" = 1.26.3 ]
    [ "$EL9_BASE_RELEASE" = "$base_release" ]
    [ "$EL9_HOTFIX_RELEASE" = "$base_release.0.1.hp1" ]
    [ "$EL9_SOURCE_FILE" = "$source_file" ]
    [ "$EL9_SOURCE_REMOTE_FILE" = "nginx-1.26.3-$base_release.src.rpm" ]
    [ "$EL9_SOURCE_SHA256" = "$source_sha256" ]
    [ "$EL9_SOURCE_URL" = "$source_url" ]
    [ -z "$EL9_MODULARITY_LABEL" ]
}

assert_target \
    rhel10:base rhel rhel redhat/ubi10 latest \
    16.el10_3.1 \
    nginx-1.26.3-16.el10_3.1.rhel.src.rpm \
    b89b1a02f55282e8cd6f69d252c9ca196b84d7d0ddacea0debbd31789836702d \
    https://cdn-ubi.redhat.com/content/public/ubi/dist/ubi10/10/x86_64/appstream/source/SRPMS/Packages/n
[ "$EL9_NEXT_RELEASE" = 16.el10_3.2 ]

assert_target \
    rockylinux10:base rockylinux rocky rockylinux 10 \
    16.el10_3.1 \
    nginx-1.26.3-16.el10_3.1.rocky.src.rpm \
    3379a462633517fdd757383e213edf53578800ba5b266cd90e68678f88783b34 \
    https://download.rockylinux.org/pub/rocky/10/AppStream/source/tree/Packages/n
[ "$EL9_NEXT_RELEASE" = 16.el10_3.2 ]

assert_target \
    oraclelinux10:base oraclelinux ol oraclelinux 10 \
    6.0.1.el10_2.7 \
    nginx-1.26.3-6.0.1.el10_2.7.src.rpm \
    7d074b68a651bc0148004af23c96b66bef7c8e5679c35dc9d7b4cdd37bb60bd2 \
    https://yum.oracle.com/repo/OracleLinux/OL10/appstream/x86_64/getPackageSource

echo 'PASS: EL10 target metadata and version ordering are valid'
