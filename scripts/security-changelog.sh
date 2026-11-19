#!/bin/bash

debian_security_patches() {
    case "$1" in
        8)
            printf '%s\n' \
                CVE-2026-123634.patch \
                CVE-2026-113425.patch \
                CVE-2026-125283-legacy-core.patch
            ;;
        9)
            printf '%s\n' \
                CVE-2026-123633.patch \
                CVE-2026-123634.patch \
                CVE-2026-123007.patch \
                CVE-2026-113425.patch \
                CVE-2026-125283-legacy-core.patch
            ;;
        10|11)
            printf '%s\n' \
                CVE-2026-123633.patch \
                CVE-2026-123640.patch \
                CVE-2026-118899-legacy.patch \
                CVE-2026-123634.patch \
                CVE-2026-123007.patch \
                CVE-2026-113425.patch \
                CVE-2026-125283-legacy-module.patch
            ;;
        12)
            printf '%s\n' \
                CVE-2023-44487.patch \
                CVE-2026-15176.patch \
                CVE-2026-93479.patch \
                CVE-2026-97205.patch \
                CVE-2026-123633.patch \
                CVE-2026-123640.patch \
                CVE-2026-118899.patch \
                CVE-2026-123634.patch \
                CVE-2026-123007-bookworm.patch \
                CVE-2026-113425.patch \
                CVE-2026-125283.patch
            ;;
        13)
            printf '%s\n' \
                CVE-2026-123633.patch \
                CVE-2026-123640.patch \
                CVE-2026-120967.patch \
                CVE-2026-118899.patch \
                CVE-2026-123634.patch \
                CVE-2026-123007.patch \
                CVE-2026-113425.patch \
                CVE-2026-121810.patch \
                CVE-2026-125283.patch
            ;;
        *)
            echo "unsupported Debian release: $1" >&2
            return 1
            ;;
    esac
}

legacy_rpm_security_patches() {
    printf '%s\n' \
        CVE-2026-123633.patch \
        CVE-2026-123640.patch \
        CVE-2026-118899-legacy.patch \
        CVE-2026-123634.patch \
        CVE-2026-123007.patch \
        CVE-2026-113425.patch \
        CVE-2026-125283-legacy-module.patch
}

security_cves_from_patches() {
    local patch cve seen=' '
    for patch in "$@"; do
        cve=$(printf '%s\n' "$patch" | sed -n 's/^\(CVE-[0-9][0-9]*-[0-9][0-9]*\).*/\1/p')
        [ -n "$cve" ] || continue
        case "$seen" in
            *" $cve "*) ;;
            *) printf '%s\n' "$cve"; seen="$seen$cve " ;;
        esac
    done
}

security_cve_description() {
    case "$1" in
        CVE-2023-44487) echo 'limit HTTP/2 Rapid Reset abuse' ;;
        CVE-2026-113425) echo 'prevent mail proxy session use-after-free' ;;
        CVE-2026-118899) echo 'handle NGX_AGAIN while reading request bodies' ;;
        CVE-2026-120967) echo 'verify stream client certificates using the SNI-selected server' ;;
        CVE-2026-121810) echo 'keep QUIC connections active while allocating streams' ;;
        CVE-2026-123007) echo 'include queued DATA in HTTP/2 flow-control checks' ;;
        CVE-2026-123633) echo 'keep active HTTP/2 connections out of the reusable queue' ;;
        CVE-2026-123634) echo 'defer freeing resolver contexts until callbacks complete' ;;
        CVE-2026-123640) echo 'validate ClientHello extensions in ssl_preread' ;;
        CVE-2026-125283) echo 'use the actual try_files script output length' ;;
        CVE-2026-15176) echo 'reject unsafe alias mapping after URI rewrites' ;;
        CVE-2026-93479) echo 'protect reserved script-engine memory' ;;
        CVE-2026-97205) echo 'bound pending asynchronous request operations' ;;
        *) echo "missing changelog description for $1" >&2; return 1 ;;
    esac
}

security_changelog_lines() {
    local format=$1 cve description prefix
    shift
    case "$format" in
        debian) prefix='  *' ;;
        rpm) prefix='-' ;;
        *) echo "unsupported changelog format: $format" >&2; return 1 ;;
    esac
    while IFS= read -r cve; do
        description=$(security_cve_description "$cve") || return
        printf '%s Fix %s: %s.\n' "$prefix" "$cve" "$description"
    done < <(security_cves_from_patches "$@")
}

security_changelog_assert_cves() {
    local changelog=$1 cve
    shift
    while IFS= read -r cve; do
        grep -qF "$cve" "$changelog" || {
            echo "missing $cve from package changelog" >&2
            return 1
        }
    done < <(security_cves_from_patches "$@")
}
