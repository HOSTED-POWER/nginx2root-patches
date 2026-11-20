#!/bin/bash
# Fail when Rocky's latest security package changes enough to revisit handover.
set -euo pipefail

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
archive=nginx2root-patches-v1.7.0-rockylinux-el10-base-x86_64.tar.xz
curl -fsSLo "$work/$archive" \
    "https://github.com/HOSTED-POWER/nginx2root-patches/releases/download/v1.7.0/$archive"
tar -C "$work" -xJf "$work/$archive"
bundle="$work/${archive%.tar.xz}"

docker run --rm -v "$bundle:/bundle:ro" rockylinux:10 bash -lc '
    set -euo pipefail
    official_evr=2:1.26.3-16.el10_3.1.0.1
    hotfix_evr=2:1.26.3-16.el10_3.1.0.1.hp1
    core_cves=(
        CVE-2026-123007
        CVE-2026-123633
        CVE-2026-123634
        CVE-2026-113425
        CVE-2026-121810
    )
    additional_cves=(
        CVE-2026-123640
        CVE-2026-120967
        CVE-2026-118899
        CVE-2026-125283
    )

    hotfix_package=$(find /bundle -maxdepth 1 -type f \
        -name "nginx-1.26.3-*.x86_64.rpm" -print -quit)
    [ -n "$hotfix_package" ]
    [ "$(rpm -qp --qf "%{EPOCHNUM}:%{VERSION}-%{RELEASE}" "$hotfix_package")" = \
        "$hotfix_evr" ]
    hotfix_changelog=$(mktemp)
    rpm -qp --changelog "$hotfix_package" > "$hotfix_changelog"
    for cve in "${core_cves[@]}" "${additional_cves[@]}"; do
        grep -qF "$cve" "$hotfix_changelog" || {
            echo "Published v1.7.0 Rocky package does not document $cve" >&2
            exit 1
        }
    done

    dnf -q -y --enablerepo=security install nginx >/dev/null
    installed_evr=$(rpm -q --qf "%{EPOCHNUM}:%{VERSION}-%{RELEASE}" nginx)
    [ "$installed_evr" = "$official_evr" ] || {
        echo "Rocky security now provides $installed_evr; reassess package coverage and ordering" >&2
        exit 1
    }

    changelog=$(mktemp)
    rpm -q --changelog nginx > "$changelog"
    for cve in "${core_cves[@]}"; do
        grep -qF "$cve" "$changelog" || {
            echo "Rocky security package no longer documents required $cve" >&2
            exit 1
        }
    done
    for cve in "${additional_cves[@]}"; do
        if grep -qF "$cve" "$changelog"; then
            echo "Rocky security now documents $cve; reassess whether the official package fully supersedes v1.7.0" >&2
            exit 1
        fi
    done
'

echo 'PASS: Rocky Linux 10 security RPM still covers five of the nine v1.7.0 CVEs'
