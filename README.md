# nginx2root patches for Debian NGINX

Backported Debian packages for the November 2026 NGINX security fixes, built by
[Hosted Power](https://www.hosted-power.com/) for systems that cannot wait for
the stable-security update. The repository contains the exact patches, pinned
Debian source inputs, reproducible build scripts, and package tests.

**Install Debian's official security update as soon as it is available.** These
are temporary, unofficial packages. Their version is deliberately lower than
Debian's expected update, so a normal `apt upgrade` replaces them automatically.

[![Debian Security Tracker showing Bookworm and Trixie vulnerable to CVE-2026-123007 on 19 November 2026](docs/debian-tracker-CVE-2026-123007-2026-11-19.png)](https://security-tracker.debian.org/tracker/CVE-2026-123007)

*Debian Security Tracker on 19 November 2026. Click the screenshot for the live status.*

## First release: Debian 12 and 13

The `v1.0.0` release contains complete amd64 package sets:

| Debian | Base package | Hotfix package | Included fixes |
|---|---|---|---|
| 12 Bookworm | `1.22.1-9+deb12u10` | `1.22.1-9+deb12u10.1~hp1` | CVE-2026-123007, CVE-2026-123633, CVE-2026-123634, CVE-2026-113425 |
| 13 Trixie | `1.26.3-3+deb13u10` | `1.26.3-3+deb13u10.1~hp1` | the same four, plus CVE-2026-121810 (HTTP/3) |

Debian 9 through 11 are being evaluated separately. They will only be published
where the vulnerability applies and the backport can be built and tested against
that release's actual NGINX package and module ABI.

## Download and install

Download the bundle for the exact Debian major version from
[Releases](https://github.com/HOSTED-POWER/nginx2root-patches/releases), then:

```bash
sha256sum -c SHA256SUMS
tar -xJf nginx2root-patches-v1.0.0-debian12-amd64.tar.xz
cd nginx2root-patches-v1.0.0-debian12-amd64
sha256sum -c SHA256SUMS
sudo ./install.sh
```

Use the Debian 13 bundle on Trixie. The installer checks the Debian release and
architecture, validates the existing NGINX configuration, and upgrades exactly
the matching packages already installed on the host. It does not add unused
modules or metapackages. It validates NGINX again afterward and, if the service
was active before the upgrade, confirms that it remains active.

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

## Safe upgrade path

The version ordering is intentional:

```text
Debian base < Hosted Power hotfix < Debian point update / next security update
```

For example:

```text
1.22.1-9+deb12u10 < 1.22.1-9+deb12u10.1~hp1 < 1.22.1-9+deb12u10.1
```

No pin, hold, epoch, diversion, or package-name change is used. Once Debian ships
a higher fixed version, normal APT and unattended-upgrades can replace the hotfix.

## Build and test

On a host with Docker:

```bash
./build.sh
./release.sh
```

The build:

1. downloads exact Debian source archives and verifies pinned SHA-256 hashes;
2. applies Debian's existing quilt series, then the applicable reviewed security patches;
3. checks the security-sensitive source conditions after patching;
4. builds unprivileged inside clean `debian:12` and `debian:13` containers;
5. upgrades a stock container, preserves the NGINX module ABI, runs `nginx -t`,
   and serves an HTTP/2 smoke request;
6. confirms the hotfix sorts above the vulnerable package and below Debian's update.

The committed patches are copied from Debian's fixed `nginx 1.30.6-4` source
package and retain their upstream commit links and authorship. Bookworm needs one
small context adaptation in `scripts/build-deb.sh`; the resulting source semantics
are checked by `scripts/test-patches.sh`.

## Scope

- Architectures in `v1.0.0`: amd64 only.
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
