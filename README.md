# nginx2root patches for Debian and Enterprise Linux NGINX

Backported Debian and Enterprise Linux packages for the
November 2026 NGINX security fixes, built by
[Hosted Power](https://www.hosted-power.com/). The repository contains the exact
patches, pinned source inputs, reproducible build scripts, and package-upgrade
tests.

These packages contain the complete fixes for every nginx2root vulnerability that
applies to each release. They are not a mitigation and need no follow-up.

The packages preserve the distribution build configuration and package layout.
Their versions are deliberately ordered below the next distribution update, so if
your distribution ships its own update later, it takes over automatically through
normal package upgrades.

**Current status (19 November 2026):** `v1.6.0` adds the native Rocky Linux 8
AppStream 1.24 package family. `v1.5.0` adds the required native Oracle Linux 10
package family. `v1.4.0` contains 13 native EL9 vendor/stream package
families, alongside the existing Debian and CentOS 7/8 releases. The signed Hosted Power APT
repository also carries the complete Debian 12 and 13 `hp3` package sets. Debian
12 currently selects `hp3`. Debian 13 now selects Debian's newer
`1.26.3-3+deb13u11` automatically; inspection of that source package confirms
that it contains all nine applicable NGINX 1.30.7 security patches listed here.

## Keep HTTP/2 on

**Disabling HTTP/2 does not fix nginx2root.** It only blocks CVE-2026-123007 and
CVE-2026-123633. The other three stay open: the resolver (CVE-2026-123634), the
mail proxy (CVE-2026-113425) and HTTP/3 (CVE-2026-121810). It also costs
performance for every client. These packages fix all applicable issues, so
HTTP/2 can stay enabled.

If you disabled HTTP/2 as a stopgap: install the packages (the upgrade restarts
NGINX), re-enable HTTP/2 (`listen 443 ssl http2;` on Debian 9–12 and CentOS 7/8,
`http2 on;` on Debian 13), then run `nginx -t` and reload.

[![Debian Security Tracker showing Bookworm and Trixie vulnerable to CVE-2026-123007 on 19 November 2026](docs/debian-tracker-CVE-2026-123007-2026-11-19.png)](https://security-tracker.debian.org/tracker/CVE-2026-123007)

*Debian Security Tracker on 19 November 2026. Click the screenshot for the live status.*

## Packages: Debian 8 through 13 and Enterprise Linux 7 through 10

The `v1.3.2` release contains complete x86-64 package sets. Its `hp3` package
revision upgrades the earlier builds while remaining below the next distribution
update. Every package changelog names each included CVE explicitly, so standard
installed-package changelog checks, `rpm -q --changelog`, and CVE audit tools
recognize the fixes. On Debian, inspect the installed evidence directly with
`zgrep CVE-2026 /usr/share/doc/nginx/changelog.Debian.gz`; `apt changelog`
consults repository metadata and is not reliable for third-party packages:

| Debian | Base package | Hotfix package | Included fixes |
|---|---|---|---|
| 8 Jessie | `1.6.2-5+deb8u10` | `1.6.2-5+deb8u10.1~hp3` | CVE-2026-113425, CVE-2026-123634, CVE-2026-125283 |
| 9 Stretch | `1.10.3-1+deb9u10` | `1.10.3-1+deb9u10.1~hp3` | CVE-2026-113425, CVE-2026-123007, CVE-2026-123633, CVE-2026-123634, CVE-2026-125283 |
| 10 Buster | `1.14.2-2+deb10u9` | `1.14.2-2+deb10u9.1~hp3` | the Stretch fixes plus CVE-2026-118899 and CVE-2026-123640 |
| 11 Bullseye | `1.18.0-6.1+deb11u9` | `1.18.0-6.1+deb11u9.1~hp3` | the same seven fixes as Buster |
| 12 Bookworm | `1.22.1-9+deb12u10` | `1.22.1-9+deb12u10.1~hp3` | the same seven, plus CVE-2026-15176, CVE-2026-93479, CVE-2026-97205 and additional CVE-2023-44487 hardening |
| 13 Trixie | `1.26.3-3+deb13u10` | `1.26.3-3+deb13u10.1~hp3` | all nine applicable NGINX 1.30.7 fixes, including CVE-2026-120967 and CVE-2026-121810 |

Debian's official Trixie `1.26.3-3+deb13u11` package now supersedes the Trixie
hotfix through normal version ordering. Its source has the same nine relevant
patches, including the HTTP/2, resolver, mail, QUIC, request-body, stream SNI,
`ssl_preread`, and `try_files` fixes. The Debian security tracker may lag the
package archive briefly while its fixed-version data is updated.

Debian 8 NGINX predates HTTP/2, so CVE-2026-123007 and CVE-2026-123633 do not
apply. Its package contains all three fixes applicable to that old source tree. Debian 8 through
11 use source packages from Freexian Extended LTS.
Their older NGINX trees require small context adaptations and, for Debian 9 and
10, the upstream SMTP duplicate-resolution prerequisite from 2019. Every adapted
source tree is checked for the security-sensitive conditions before it is built.

| Distribution | Base package | Hotfix package | Included fixes |
|---|---|---|---|
| CentOS 7 archived EPEL | `1:1.20.1-10.el7` | `1:1.20.1-10.el7.0.1.hp3` | seven applicable fixes: CVE-2026-113425, CVE-2026-118899, CVE-2026-123007, CVE-2026-123633, CVE-2026-123634, CVE-2026-123640, CVE-2026-125283 |
| CentOS 8 AppStream 1.14 (original/default) | `1:1.14.1-9.module_el8.0.0+184+e34fea82` | `1:1.14.1-9.module_el8.0.0+184+e34fea82.0.1.hp3` | the same seven applicable fixes |
| CentOS 8 AppStream 1.16 | `1:1.16.1-2.module_el8.4.0+820+127618ce.1` | `1:1.16.1-2.module_el8.4.0+820+127618ce.1.0.1.hp3` | the same seven applicable fixes |
| CentOS 8 AppStream 1.18 | `1:1.18.0-3.module_el8.4.0+818+5ada96a6.1` | `1:1.18.0-3.module_el8.4.0+818+5ada96a6.1.0.1.hp3` | the same seven applicable fixes |
| CentOS 8 AppStream 1.20 | `1:1.20.0-2.module_el8.5.0+899+43b718f6` | `1:1.20.0-2.module_el8.5.0+899+43b718f6.0.1.hp3` | the same seven applicable fixes |

The CentOS 7 package set targets only NGINX installed from the archived EPEL 7
package family. The installer rejects nginx.org, control-panel, and other package
families rather than attempting an unsafe cross-vendor replacement.

CentOS Linux 8 shipped NGINX through AppStream from its first 1.14 default
stream onward. Separate bundles preserve the exact package version, module
stream identity, modularity label, package layout, and ABI for each of the four
final official CentOS Linux 8 streams. The installer upgrades only an exact
matching package family and rejects cross-stream or cross-vendor replacement.

## AlmaLinux 8 through 10

AlmaLinux now has complete official fixes for the five headline NGINX2Root CVEs
on every supported stream. The follow-up packages matter: on AlmaLinux 9 these
are the default 1.20 `.alma.4`, 1.24 `.alma.4`, and 1.26 `.alma.2` builds; on
AlmaLinux 10 it is the 1.26 `.alma.3` build. Earlier `.alma.2`/`.alma.3` packages
from the initial advisories fixed only the two HTTP/2 issues. Update from the
normal AlmaLinux repositories rather than installing a CentOS bundle:

```bash
sudo dnf update nginx 'nginx-*'
sudo nginx -t
```

The CentOS Linux 8 bundles must not be installed on AlmaLinux. Retired
AlmaLinux 8 streams 1.14, 1.16, 1.18, 1.20, and 1.22 should be migrated to the
supported 1.24 stream. AlmaLinux 9's retired 1.22 stream has not received these
fixes. The `v1.4.0` release includes an exact native package for that retired
stream where an immediate stream migration is not practical.

## Rocky Linux 8

Rocky Linux 8's supported NGINX 1.24 AppStream still ships vulnerable
`1:1.24.0-3.module+el8.10.0+40424+5b12c67a.6`. The `v1.6.0` release provides
the exact native hotfix
`1:1.24.0-3.module+el8.10.0+40424+5b12c67a.6.0.1.hp1` with all seven applicable
fixes. It preserves Rocky's package split, configuration, ABI, and
`nginx:1.24:8100020261111132044:e155f54d` module identity.

The installer rejects CentOS, AlmaLinux, Oracle Linux, another Rocky release,
another stream, and any package release other than the exact Rocky base or this
hotfix. A later Rocky `.7` package supersedes it through normal DNF version
ordering.

## Enterprise Linux 9

The `v1.4.0` release adds 13 native x86-64 package families. Each bundle is
built from that vendor's exact SRPM and preserves its epoch, release lineage,
modularity label, package split, configuration, and module ABI. Installers
reject another vendor, stream, package release, or architecture.

| Vendor | Included NGINX families |
|---|---|
| Red Hat Enterprise Linux 9 | base 1.20, AppStream 1.22, 1.24, and 1.26 |
| AlmaLinux 9 | retired AppStream 1.22 only; supported streams have official fixes |
| Rocky Linux 9 | base 1.20, AppStream 1.22, 1.24, and 1.26 |
| Oracle Linux 9 | base 1.20, AppStream 1.22, 1.24, and 1.26 |

The 1.20, 1.22, and 1.24 bundles contain the seven applicable fixes. The 1.26
bundles contain all nine applicable fixes, including stream SNI verification
and the HTTP/3 connection-lifetime fix. Every package changelog names each CVE.

## Enterprise Linux 10

RHEL 10, Rocky Linux 10, and AlmaLinux 10 now carry the fixed
`1.26.3-16.el10_3.1` package lineage in their normal repositories and need no
Hosted Power package. Oracle Linux 10 still ships
`2:1.26.3-6.0.1.el10_2.7`; `v1.5.0` provides the exact native hotfix
`2:1.26.3-6.0.1.el10_2.7.0.1.hp1` with all nine applicable fixes.

The Oracle Linux 10 bundle preserves the original package split, configuration,
epoch, ABI, and non-modular identity. Its installer rejects every other OS,
release, package family, and architecture.

## Download and install

Download the bundle for the matching Debian or Enterprise Linux package family from
[Releases](https://github.com/HOSTED-POWER/nginx2root-patches/releases), then:

```bash
sha256sum --ignore-missing -c SHA256SUMS
tar -xJf nginx2root-patches-v1.3.2-debian12-amd64.tar.xz
cd nginx2root-patches-v1.3.2-debian12-amd64
sha256sum -c SHA256SUMS
sudo ./install.sh
```

Choose the bundle matching the host's exact Debian major release. The installer
checks the Debian release and architecture, validates the existing NGINX
configuration, and upgrades exactly the matching packages already installed on
the host. It does not add unused modules or metapackages. It validates NGINX
again afterward and, if the service was active before the upgrade, confirms that
it remains active.

The bundle contains matching packages for every module and metapackage built from
Debian's NGINX source package. This matters for `libnginx-mod-mail`, which carries
the CVE-2026-113425 fix, and for version-locked Debian metapackages.

Verify immediately after installation:

```bash
sudo nginx -t
systemctl is-active nginx
nginx -v
```

The packages are also published in Hosted Power's existing Debian repository for
managed systems. The GitHub release is provided so the build and binaries are
publicly auditable and independently usable.

For CentOS 7 with the archived EPEL package family:

```bash
sha256sum --ignore-missing -c SHA256SUMS
tar -xJf nginx2root-patches-v1.3.2-centos7-epel-x86_64.tar.xz
cd nginx2root-patches-v1.3.2-centos7-epel-x86_64
sha256sum -c SHA256SUMS
sudo ./install-rpm.sh
```

The RPM installer upgrades only already-installed NGINX packages from the bundle,
accepts the vendor base or either earlier `hp1`/`hp2` build, checks configuration before
and after, and verifies that an active service stays active.

For CentOS Linux 8, first identify the installed AppStream family:

```bash
rpm -q nginx
```

Download the matching `centos8-appstream-1.14`, `1.16`, `1.18`, or `1.20`
bundle. For example, for the original/default 1.14 line:

```bash
sha256sum --ignore-missing -c SHA256SUMS
tar -xJf nginx2root-patches-v1.3.2-centos8-appstream-1.14-x86_64.tar.xz
cd nginx2root-patches-v1.3.2-centos8-appstream-1.14-x86_64
sha256sum -c SHA256SUMS
sudo ./install-centos8-rpm.sh
```

The CentOS 8 installer has the same pre/post configuration and service checks,
and additionally verifies the exact AppStream package release before upgrading.

For EL9, identify the vendor and installed family, then download the exact
matching bundle:

```bash
cat /etc/os-release
rpm -q nginx
tar -xJf nginx2root-patches-v1.4.0-rockylinux-el9-1.26-x86_64.tar.xz
cd nginx2root-patches-v1.4.0-rockylinux-el9-1.26-x86_64
sha256sum -c SHA256SUMS
sudo ./install-el9-rpm.sh
```

The EL9 installer upgrades only the NGINX packages already installed, runs
`nginx -t` before and after, confirms an active service remains active, and
restarts it if any NGINX process still uses the replaced executable.

For Rocky Linux 8 with the 1.24 AppStream enabled:

```bash
tar -xJf nginx2root-patches-v1.6.0-rockylinux-el8-1.24-x86_64.tar.xz
cd nginx2root-patches-v1.6.0-rockylinux-el8-1.24-x86_64
sha256sum -c SHA256SUMS
sudo ./install-el8-rpm.sh
```

For Oracle Linux 10:

```bash
tar -xJf nginx2root-patches-v1.5.0-oraclelinux-el10-base-x86_64.tar.xz
cd nginx2root-patches-v1.5.0-oraclelinux-el10-base-x86_64
sha256sum -c SHA256SUMS
sudo ./install-el10-rpm.sh
```

## Safe upgrade path

The version ordering is intentional:

```text
distribution base < Hosted Power hotfix < distribution point update
```

For example:

```text
1.22.1-9+deb12u10 < ...~hp1 < ...~hp2 < ...~hp3 < 1.22.1-9+deb12u10.1
```

No pin, hold, new epoch, diversion, or package-name change is used. A higher
distribution package replaces the matching hotfix through normal package updates.

## Build and test

On a host with Docker:

```bash
./build.sh
./release.sh
./build-el8.sh
VERSION=v1.6.0 ./release-el8.sh
JOBS=6 ./build-el9.sh
VERSION=v1.4.0 ./release-el9.sh
./build-el10.sh
VERSION=v1.5.0 ./release-el10.sh
```

The build:

1. downloads exact Debian, archived EPEL, and CentOS AppStream source packages
   and verifies pinned SHA-256 hashes;
2. applies the vendor source package changes, then the applicable reviewed security patches;
3. checks the security-sensitive source conditions after patching;
4. builds unprivileged inside clean matching `debian:8` through `debian:13`,
   `centos:7`, `centos:8`, and `rockylinux:8` containers;
5. upgrades a stock container, preserves the NGINX module ABI, runs `nginx -t`,
   starts fresh workers, and exercises HTTP/1.1, HTTP/2, reverse proxying, mail,
   stream, and representative packaged dynamic modules;
6. confirms each hotfix sorts above the vulnerable package and below a future vendor update.

The committed security patches come from upstream NGINX 1.30.7 and Debian's
reviewed Bookworm and Trixie security branches, retaining upstream links and
authorship. Older
releases need narrowly scoped context adaptations in `scripts/build-deb.sh` and
`scripts/build-centos8-rpm.sh`; the resulting source semantics are checked by
`scripts/test-patches.sh`.

## Scope

- Architectures through `v1.6.0`: Debian amd64 and Enterprise Linux x86-64 only.
- Debian 8, 9, 10, and 11 and CentOS 7 and 8 are EOL releases. Their NGINX
  hotfixes do not provide security support for the rest of the operating system.
- Debian 8 through 11 source provenance is
  Freexian Extended LTS, and users must separately ensure their full operating
  system remains supported and patched.
- These packages preserve the distribution's configuration paths, maintainer scripts,
  compile options, and dynamic-module ABI.
- They do not make an exposed NGINX configuration safe by themselves unless the
  matching `nginx` binary and any installed affected module are upgraded.
- No warranty is provided. Review the patches and checksums before deployment.

## Sources

- [Debian tracker: CVE-2026-123007](https://security-tracker.debian.org/tracker/CVE-2026-123007)
- [Debian tracker: CVE-2026-123633](https://security-tracker.debian.org/tracker/CVE-2026-123633)
- [Debian tracker: CVE-2026-123634](https://security-tracker.debian.org/tracker/CVE-2026-123634)
- [Debian tracker: CVE-2026-113425](https://security-tracker.debian.org/tracker/CVE-2026-113425)
- [Debian tracker: CVE-2026-121810](https://security-tracker.debian.org/tracker/CVE-2026-121810)
- [NGINX security advisories](https://nginx.org/en/security_advisories.html)
- [Ubuntu analysis: CVE-2026-118899](https://ubuntu.com/security/CVE-2026-118899)
- [Ubuntu analysis: CVE-2026-123640](https://ubuntu.com/security/CVE-2026-123640)
- [Ubuntu analysis: CVE-2026-125283](https://ubuntu.com/security/CVE-2026-125283)
- [Debian fixed source package](https://tracker.debian.org/pkg/nginx)
- [Freexian Extended LTS repository](https://deb.freexian.com/extended-lts/)
- [Archived EPEL 7 packages](https://archives.fedoraproject.org/pub/archive/epel/7/)
- [Archived CentOS Linux 8 AppStream packages](https://vault.centos.org/8.5.2111/AppStream/)
- [Rocky Linux 8 AppStream source packages](https://download.rockylinux.org/pub/rocky/8/AppStream/source/tree/Packages/n/)
- [AlmaLinux NGINX security update guidance](https://almalinux.org/blog/2026-11-18-nginx2root/)
- [AlmaLinux 9 erratum ALSA-2026-A025](https://errata.almalinux.org/9/ALSA-2026-A025.html)
- [AlmaLinux 10 erratum ALSA-2026-A024](https://errata.almalinux.org/10/ALSA-2026-A024.html)
