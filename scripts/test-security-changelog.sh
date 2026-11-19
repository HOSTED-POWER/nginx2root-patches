#!/bin/bash
set -euo pipefail

HERE=$(dirname "$(realpath "$0")")
. "$HERE/security-changelog.sh"

mapfile -t trixie_patches < <(debian_security_patches 13)
mapfile -t trixie_cves < <(security_cves_from_patches "${trixie_patches[@]}")
[ "${#trixie_cves[@]}" -eq 9 ]
[ "${trixie_cves[0]}" = CVE-2026-123633 ]
[ "${trixie_cves[8]}" = CVE-2026-125283 ]

mapfile -t bookworm_patches < <(debian_security_patches 12)
mapfile -t bookworm_cves < <(security_cves_from_patches "${bookworm_patches[@]}")
[ "${#bookworm_cves[@]}" -eq 11 ]
printf '%s\n' "${bookworm_cves[@]}" | grep -qx CVE-2023-44487
printf '%s\n' "${bookworm_cves[@]}" | grep -qx CVE-2026-123007

mapfile -t rpm_patches < <(legacy_rpm_security_patches)
mapfile -t rpm_cves < <(security_cves_from_patches "${rpm_patches[@]}")
[ "${#rpm_cves[@]}" -eq 7 ]

debian_lines=$(security_changelog_lines debian "${trixie_patches[@]}")
rpm_lines=$(security_changelog_lines rpm "${rpm_patches[@]}")
for cve in "${trixie_cves[@]}"; do
    printf '%s\n' "$debian_lines" | grep -qF "Fix $cve:"
done
for cve in "${rpm_cves[@]}"; do
    printf '%s\n' "$rpm_lines" | grep -qF -- "- Fix $cve:"
done

if security_changelog_lines debian CVE-2099-999999.patch >/dev/null 2>&1; then
    echo 'unknown CVE unexpectedly produced a changelog line' >&2
    exit 1
fi

echo 'PASS: security changelog generation covers every selected CVE'
