# Complete NGINX Security Packages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the existing Debian and CentOS hotfix packages, then add safe native packages for the remaining prioritized distributions without changing vendor configuration, package layout, module ABI, or service behavior.

**Architecture:** Every target starts from the exact vendor source package and receives only applicable upstream or vendor-reviewed security patches. Each package family has explicit source-condition tests, version-order tests, wrong-family rejection, package upgrade tests, `nginx -t`, live HTTP/1.1 and HTTP/2 requests, proxying, dynamic-module checks, and active-worker verification before release publication.

**Tech Stack:** Bash, Debian source packages and quilt, RPM/SRPM and rpmbuild, Docker/Podman-compatible containers, NGINX, curl, nghttp2, GitHub Releases.

---

### Task 1: Correct the security patch inventory

**Files:**
- Create: `patches/CVE-2023-44487.patch`
- Create: `patches/CVE-2026-118899.patch`
- Create: `patches/CVE-2026-120967.patch`
- Create: `patches/CVE-2026-123640.patch`
- Create: `patches/CVE-2026-125283.patch`
- Create: `patches/CVE-2026-15176.patch`
- Create: `patches/CVE-2026-93479.patch`
- Create: `patches/CVE-2026-97205.patch`
- Modify: `scripts/test-patches.sh`

- [ ] Import the exact reviewed patches from upstream NGINX 1.30.7 and Debian's Bookworm/Trixie security branches, preserving provenance headers.
- [ ] Add source-condition assertions for request-body `NGX_AGAIN`, `try_files` URI restoration, stream SNI verification, strict `ssl_preread` parsing, and the four Bookworm-only earlier fixes.
- [ ] Run `bash -n scripts/test-patches.sh` and verify the unmodified source-package fixtures fail the new assertions.

### Task 2: Apply corrected patches to existing Debian packages

**Files:**
- Modify: `scripts/build-deb.sh`
- Modify: `scripts/test-package.sh`

- [ ] Define the exact applicability map: Debian 8/9 add CVE-2026-125283; Debian 10-12 add CVE-2026-118899, CVE-2026-123640, and CVE-2026-125283; Debian 13 additionally adds CVE-2026-120967; Debian 12 alone adds CVE-2023-44487, CVE-2026-15176, CVE-2026-93479, and CVE-2026-97205.
- [ ] Adapt only patch context that differs on old source trees and make every adaptation fail closed when its expected insertion point changes.
- [ ] Expand package tests to preserve the installed module set and ABI, validate `nginx -t`, start NGINX, verify fresh workers, exercise HTTP/1.1, HTTP/2 where available, proxying, and representative installed dynamic modules.
- [ ] Build and test Debian 8 through 13 in clean matching containers.

### Task 3: Apply corrected patches to existing CentOS packages

**Files:**
- Modify: `scripts/build-rpm.sh`
- Modify: `scripts/build-centos8-rpm.sh`
- Modify: `scripts/test-rpm-package.sh`
- Modify: `scripts/test-centos8-rpm-package.sh`

- [ ] Add CVE-2026-118899, CVE-2026-123640, and CVE-2026-125283 to CentOS 7 and all CentOS 8 streams.
- [ ] Add the CVE-2026-123633 active-connection reuse guard to CentOS 8 streams 1.14, 1.16, and 1.18 as well as 1.20.
- [ ] Adapt the old 1.14 `ssl_preread` parser without adding unsupported newer protocol parsing, and make every context adaptation fail closed.
- [ ] Expand RPM package tests with the same configuration, worker, protocol, proxy, module, ABI, stream identity, and wrong-family checks used for Debian.
- [ ] Build and test CentOS 7 EPEL and all four CentOS 8 AppStream streams in clean matching containers.

### Task 4: Publish corrected existing-target release

**Files:**
- Modify: `release.sh`
- Modify: `README.md`

- [ ] Set the release version to `v1.3.1`, document the complete applicable CVE set per package family, and retain deterministic timestamps and checksums.
- [ ] Run shell syntax checks, source-condition tests, version-order tests, all package builds, all package service tests, and a second deterministic bundle build.
- [ ] Perform an explicit review covering syntax, applicability, ABI/layout preservation, installer rejection behavior, service continuity, idempotency, and validation evidence.
- [ ] Fetch `origin/main`, rebase if it advanced, rerun affected validation, then commit, push, tag, and publish all verified bundles and checksums.

### Task 5: Add RHEL-family and Fedora native packages

**Files:**
- Create: `scripts/build-el-rpm.sh`
- Create: `scripts/test-el-rpm-package.sh`
- Create: `install-el-rpm.sh`
- Modify: `versions.sh`
- Modify: `build.sh`
- Modify: `release.sh`
- Modify: `README.md`

- [ ] Pin separate vendor SRPM inputs and checksums for RHEL, Rocky, and Oracle Linux 8-10 plus Fedora 43-45; never cross-install one vendor's binary package on another vendor.
- [ ] Preserve each package's exact EVR, modularity identity where applicable, build options, subpackage set, and module ABI while sorting below the next vendor update.
- [ ] Add fail-closed vendor/version/architecture checks and test install, upgrade, wrong-vendor rejection, rollback ordering, configuration, workers, HTTP/1.1, HTTP/2, proxying, stream/mail modules, and active service state.
- [ ] Build and publish only package families whose matching clean container or VM passes every gate.

### Task 6: Add Ubuntu completion packages

**Files:**
- Create: `scripts/build-ubuntu-deb.sh`
- Create: `scripts/test-ubuntu-package.sh`
- Create: `install-ubuntu.sh`
- Modify: `versions.sh`
- Modify: `build.sh`
- Modify: `release.sh`
- Modify: `README.md`

- [ ] Pin each supported Ubuntu source package after USN-9159-1 and apply only the still-missing applicable CVE-2026-118899, CVE-2026-123640, and CVE-2026-125283 fixes.
- [ ] Preserve Ubuntu's package split, configuration, maintainer scripts, ABI, and version takeover path.
- [ ] Run the full Debian-equivalent package, protocol, proxy, module, worker, installer rejection, and version-order test suite before publishing.

### Task 7: Document bundled-product exposure

**Files:**
- Create: `docs/bundled-nginx-exposure.md`
- Modify: `README.md`

- [ ] Record verified runtime/version detection and vendor status for GitLab Omnibus, archived Kubernetes ingress-nginx, OpenResty, Nginx Proxy Manager, APISIX, Kong, Tengine, Cloud Foundry OpenResty, Plesk, and Synology.
- [ ] Clearly state that OS packages cannot patch bundled NGINX copies and give product-specific verification commands without claiming safety from package-manager state alone.

### Task 8: Investigate later ecosystems

**Files:**
- Modify: `README.md`
- Create only after verified need: target-specific SUSE/openSUSE, NixOS, and OpenWrt build/test files.

- [ ] Recheck current vendor/package status for SUSE/openSUSE, NixOS, and OpenWrt after the higher-priority releases.
- [ ] Add packages only where no supported vendor fix exists and a matching service-level test environment is available.

