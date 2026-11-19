# RHEL and Rocky Linux 10 Hotfixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publish native RHEL 10 and Rocky Linux 10 NGINX hotfix bundles after confirming their current `1.26.3-16.el10_3.1` packages do not contain the November 2026 NGINX fixes.

**Architecture:** Extend the existing EL10 target matrix while preserving one exact SRPM and one OS guard per vendor. Reuse the proven EL9/EL10 build, package, installer, and runtime tests; never install one vendor's RPMs on another vendor. Release RHEL, Rocky, and Oracle bundles together under a new EL10 release and document official-vendor takeover ordering.

**Tech Stack:** Bash, RPM/rpmbuild, Docker, RHEL UBI 10, Rocky Linux 10, Oracle Linux 10, NGINX HTTP/2 runtime tests, GitHub Releases.

---

### Task 1: Lock the EL10 vendor matrix

**Files:**
- Modify: `versions.sh`
- Create: `scripts/test-el10-targets.sh`

- [ ] **Step 1: Add a failing target-matrix test**

Assert that `el10_targets` returns `rhel10:base`, `rockylinux10:base`, and `oraclelinux10:base`; each target must expose the expected OS ID, image, epoch, NGINX version, base release, SRPM name and SHA-256, and a future vendor release that sorts above the hotfix.

- [ ] **Step 2: Run the test and verify it fails**

Run: `bash scripts/test-el10-targets.sh`

Expected: failure because RHEL 10 and Rocky Linux 10 are not yet defined.

- [ ] **Step 3: Add exact native target metadata**

Use these pinned SRPMs:

```text
RHEL 10:  nginx-1.26.3-16.el10_3.1.src.rpm
SHA-256:  b89b1a02f55282e8cd6f69d252c9ca196b84d7d0ddacea0debbd31789836702d

Rocky 10: nginx-1.26.3-16.el10_3.1.src.rpm
SHA-256:  3379a462633517fdd757383e213edf53578800ba5b266cd90e68678f88783b34
```

Set the hotfix release to `16.el10_3.1.0.1.hp1` and test ordering below `16.el10_3.2`.

- [ ] **Step 4: Run the target test**

Run: `bash scripts/test-el10-targets.sh`

Expected: `PASS: EL10 target metadata and version ordering are valid`.

### Task 2: Build and test each native package family

**Files:**
- Modify: `build-el10.sh`
- Modify: `release-el10.sh`
- Reuse: `scripts/build-el9-rpm.sh`
- Reuse: `scripts/test-el9-rpm-package.sh`
- Reuse: `install-el10-rpm.sh`

- [ ] **Step 1: Generalize user-facing EL10 script descriptions**

Change Oracle-only wording to Enterprise Linux 10 wording and set the release default to `v1.7.0`.

- [ ] **Step 2: Fetch and verify all three SRPMs**

Run: `scripts/fetch-sources.sh sources el10`

Expected: all pinned checksums pass.

- [ ] **Step 3: Build and test all EL10 targets**

Run: `./build-el10.sh`

Expected: all three package families build and pass package-set, changelog, ABI, HTTP/1.1, HTTP/2, reverse-proxy, mail, stream, dynamic-module, and fresh-worker checks.

- [ ] **Step 4: Create deterministic release bundles**

Run: `VERSION=v1.7.0 ./release-el10.sh`

Expected: one x86-64 archive per vendor plus `SHA256SUMS-v1.7.0-el10`.

### Task 3: Correct public status and publish

**Files:**
- Modify: `README.md`
- Create: `docs/releases/v1.7.0.md`

- [ ] **Step 1: Correct the EL10 status**

State that AlmaLinux 10 has a complete official `.alma.3` fix, while RHEL 10 and Rocky Linux 10 `1.26.3-16.el10_3.1` remain affected and are covered by `v1.7.0`; retain Oracle Linux 10 coverage.

- [ ] **Step 2: Document exact install and takeover behavior**

List all three base and hotfix EVRs and explain that a future vendor `.2` release supersedes `.1.0.1.hp1` automatically.

- [ ] **Step 3: Run final static and package validation**

Run: `bash -n build-el10.sh release-el10.sh install-el10-rpm.sh scripts/*.sh && bash scripts/test-security-changelog.sh && bash scripts/test-el10-targets.sh`

Expected: every command exits zero.

- [ ] **Step 4: Review the complete diff**

Check vendor isolation, package ordering, source checksums, release naming, deterministic timestamps, documentation accuracy, and absence of unrelated changes.

- [ ] **Step 5: Commit, push, and publish the release**

Commit message: `Add RHEL and Rocky Linux 10 NGINX hotfix packages`

Publish `v1.7.0` with all EL10 archives and its top-level checksum file, then verify each public asset checksum against the local artifact.
