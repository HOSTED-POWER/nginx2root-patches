# nginx2root patches for Debian and archived EPEL NGINX

Backported Debian and CentOS 7 EPEL packages for the November 2026 NGINX
security fixes, built by [Hosted Power](https://www.hosted-power.com/). The
repository contains the exact patches, pinned source inputs, reproducible build
scripts, and package-upgrade tests.

The packages preserve the distribution build configuration and package layout.
Their versions are deliberately ordered below the next distribution update, so
normal package upgrades can hand back to the distribution package automatically.

[![Debian Security Tracker showing Bookworm and Trixie vulnerable to CVE-2026-123007 on 19 November 2026](docs/debian-tracker-CVE-2026-123007-2026-11-19.png)](https://security-tracker.debian.org/tracker/CVE-2026-123007)

*Debian Security Tracker on 19 November 2026. Click the screenshot for the live status.*

## Packages: Debian 8 through 13 and CentOS 7 EPEL

The `v1.2.0` release contains complete x86-64 package sets:

| Debian | Base package | Hotfix package | Included fixes |
|---|---|---|---|
| 8 Jessie | `1.6.2-5+deb8u10` | `1.6.2-5+deb8u10.1~hp1` | CVE-2026-123634, CVE-2026-113425 |
| 9 Stretch | `1.10.3-1+deb9u10` | `1.10.3-1+deb9u10.1~hp1` | CVE-2026-123007, CVE-2026-123633, CVE-2026-123634, CVE-2026-113425 |
| 10 Buster | `1.14.2-2+deb10u9` | `1.14.2-2+deb10u9.1~hp1` | the same four |
| 11 Bullseye | `1.18.0-6.1+deb11u9` | `1.18.0-6.1+deb11u9.1~hp1` | the same four |
| 12 Bookworm | `1.22.1-9+deb12u10` | `1.22.1-9+deb12u10.1~hp1` | CVE-2026-123007, CVE-2026-123633, CVE-2026-123634, CVE-2026-113425 |
| 13 Trixie | `1.26.3-3+deb13u10` | `1.26.3-3+deb13u10.1~hp1` | the same four, plus CVE-2026-121810 (HTTP/3) |

Debian 8 NGINX predates HTTP/2, so CVE-2026-123007 and CVE-2026-123633 do not
apply. Its package contains the resolver and mail proxy fixes. Debian 8 through
11 use source packages from Freexian Extended LTS.
Their older NGINX trees require small context adaptations and, for Debian 9 and
10, the upstream SMTP duplicate-resolution prerequisite from 2019. Every adapted
source tree is checked for the security-sensitive conditions before it is built.

| Distribution | Base package | Hotfix package | Included fixes |
|---|---|---|---|
| CentOS 7 archived EPEL | `1:1.20.1-10.el7` | `1:1.20.1-10.el7.0.1.hp1` | CVE-2026-123007, CVE-2026-123633, CVE-2026-123634, CVE-2026-113425 |

The CentOS 7 package set targets only NGINX installed from the archived EPEL 7
package family. The installer rejects nginx.org, control-panel, and other package
families rather than attempting an unsafe cross-vendor replacement.

## AlmaLinux 8 through 10

AlmaLinux released official fixed NGINX packages on 18 November 2026 for every
stream still in its RHEL lifecycle. AlmaLinux 8 users should select the supported
`nginx:1.24` stream; AlmaLinux 9 has fixed default 1.20 and supported 1.24/1.26
streams; AlmaLinux 10 has fixed default 1.26 packages. Update these systems from
the normal AlmaLinux repositories:

```bash
sudo dnf update nginx 'nginx-*'
sudo nginx -t
```

Retired AlmaLinux 8 streams 1.14, 1.16, 1.18, 1.20, and 1.22 are not covered by
this repository. Migrate those installations to the supported 1.24 stream.

## Download and install

Download the bundle for the exact Debian major version from
[Releases](https://github.com/HOSTED-POWER/nginx2root-patches/releases), then:

```bash
sha256sum -c SHA256SUMS
tar -xJf nginx2root-patches-v1.2.0-debian12-amd64.tar.xz
cd nginx2root-patches-v1.2.0-debian12-amd64
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
sha256sum -c SHA256SUMS
tar -xJf nginx2root-patches-v1.2.0-centos7-epel-x86_64.tar.xz
cd nginx2root-patches-v1.2.0-centos7-epel-x86_64
sha256sum -c SHA256SUMS
sudo ./install-rpm.sh
```

The RPM installer upgrades only already-installed NGINX packages from the bundle,
checks configuration before and after, and verifies that an active service stays
active.

## Safe upgrade path

The version ordering is intentional:

```text
distribution base < Hosted Power hotfix < distribution point update
```

For example:

```text
1.22.1-9+deb12u10 < 1.22.1-9+deb12u10.1~hp1 < 1.22.1-9+deb12u10.1
```

No pin, hold, new epoch, diversion, or package-name change is used. A higher
distribution package replaces the matching hotfix through normal package updates.

## Build and test

On a host with Docker:

```bash
./build.sh
./release.sh
```

The build:

1. downloads exact Debian and archived EPEL source packages and verifies pinned SHA-256 hashes;
2. applies the vendor source package changes, then the applicable reviewed security patches;
3. checks the security-sensitive source conditions after patching;
4. builds unprivileged inside clean matching `debian:8` through `debian:13` and `centos:7` containers;
5. upgrades a stock container, preserves the NGINX module ABI, runs `nginx -t`,
   and serves an HTTP/2 smoke request;
6. confirms each hotfix sorts above the vulnerable package and below a future vendor update.

The committed security patches are copied from Debian's fixed `nginx 1.30.6-4`
source package and retain their upstream commit links and authorship. Older
releases need narrowly scoped context adaptations in `scripts/build-deb.sh`; the
resulting source semantics are checked by `scripts/test-patches.sh`.

## Scope

- Architectures in `v1.2.0`: Debian amd64 and CentOS 7 x86-64 only.
- Debian 8, 9, 10, and 11 and CentOS 7 are EOL releases. Their NGINX hotfixes do
  not provide security support for the rest of the operating system.
- Debian 8 through 11 source provenance is
  Freexian Extended LTS, and users must separately ensure their full operating
  system remains supported and patched.
- These packages preserve Debian's configuration paths, maintainer scripts,
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
- [Debian fixed source package](https://tracker.debian.org/pkg/nginx)
- [Freexian Extended LTS repository](https://deb.freexian.com/extended-lts/)
- [Archived EPEL 7 packages](https://archives.fedoraproject.org/pub/archive/epel/7/)
- [AlmaLinux NGINX security update guidance](https://almalinux.org/blog/2026-11-18-nginx2root/)
- [AlmaLinux 9 erratum ALSA-2026-A025](https://errata.almalinux.org/9/ALSA-2026-A025.html)
- [AlmaLinux 10 erratum ALSA-2026-A024](https://errata.almalinux.org/10/ALSA-2026-A024.html)
