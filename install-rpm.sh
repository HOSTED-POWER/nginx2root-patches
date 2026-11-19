#!/bin/bash
# Upgrade only installed CentOS 7 EPEL NGINX packages present in this bundle.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
    echo 'ERROR: run as root (sudo ./install-rpm.sh)' >&2
    exit 1
}

BUNDLE=$(realpath "${1:-$(dirname "$0")}")
. /etc/os-release

[ "$ID" = centos ] && [ "$VERSION_ID" = 7 ] || {
    echo 'ERROR: this bundle supports CentOS 7 only' >&2
    exit 1
}

base_evr='1:1.20.1-10.el7'
hotfix_evr='1:1.20.1-10.el7.0.1.hp1'
host_arch=$(rpm --eval '%{_arch}')

mapfile -t available_rpms < <(find "$BUNDLE" -maxdepth 1 -type f -name '*.rpm' -print | sort)
[ "${#available_rpms[@]}" -gt 0 ] || {
    echo "ERROR: no RPM packages found in $BUNDLE" >&2
    exit 1
}

declare -A bundle_by_name=()
for package in "${available_rpms[@]}"; do
    package_name=$(rpm -qp --qf '%{NAME}' "$package")
    package_evr=$(rpm -qp --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package")
    package_arch=$(rpm -qp --qf '%{ARCH}' "$package")

    [ "$package_evr" = "$hotfix_evr" ] || {
        echo "ERROR: package $package_name has unexpected version $package_evr" >&2
        exit 1
    }
    case "$package_arch" in
        noarch|"$host_arch") ;;
        *)
            echo "ERROR: package $package_name architecture $package_arch does not match $host_arch" >&2
            exit 1
            ;;
    esac
    [ -z "${bundle_by_name[$package_name]:-}" ] || {
        echo "ERROR: duplicate package $package_name in bundle" >&2
        exit 1
    }
    bundle_by_name[$package_name]=$package
done

mapfile -t installed_names < <(rpm -qa --qf '%{NAME}\n' 'nginx*' | sort -u)
printf '%s\n' "${installed_names[@]}" | grep -qx nginx || {
    echo 'ERROR: the EPEL nginx package is not installed' >&2
    exit 1
}

selected_rpms=()
for package_name in "${installed_names[@]}"; do
    package_evr=$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package_name")
    case "$package_evr" in
        "$base_evr"|"$hotfix_evr") ;;
        *)
            echo "ERROR: installed $package_name version $package_evr is not the archived EPEL 7 package family" >&2
            exit 1
            ;;
    esac
    [ -n "${bundle_by_name[$package_name]:-}" ] || {
        echo "ERROR: bundle has no matching package for installed $package_name" >&2
        exit 1
    }
    selected_rpms+=("${bundle_by_name[$package_name]}")
done

nginx -t
was_active=0
if [ -d /run/systemd/system ] && systemctl is-active --quiet nginx; then
    was_active=1
fi

yum -y localinstall "${selected_rpms[@]}"
nginx -t

if [ "$was_active" -eq 1 ]; then
    systemctl is-active --quiet nginx || {
        echo 'ERROR: nginx was active before the upgrade but is not active now' >&2
        exit 1
    }
fi

echo "PASS: upgraded installed EPEL 7 NGINX packages to $hotfix_evr"
rpm -q --qf '%{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}\n' "${installed_names[@]}" | sort
