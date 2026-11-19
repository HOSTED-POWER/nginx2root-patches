#!/bin/bash
# Upgrade one exact EL9 NGINX package family from this bundle.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
    echo 'ERROR: run as root (sudo ./install-el9-rpm.sh)' >&2
    exit 1
}

BUNDLE=$(realpath "${1:-$(dirname "$0")}")
[ -f "$BUNDLE/bundle.env" ] || {
    echo "ERROR: bundle metadata is missing from $BUNDLE" >&2
    exit 1
}
. "$BUNDLE/bundle.env"
. /etc/os-release

[ "$ID" = "$TARGET_OS_ID" ] && [ "${VERSION_ID%%.*}" = 9 ] || {
    echo "ERROR: this bundle supports $TARGET_NAME 9 only" >&2
    exit 1
}

host_arch=$(rpm --eval '%{_arch}')
declare -A bundle_by_name=()
mapfile -t available_rpms < <(find "$BUNDLE" -maxdepth 1 -type f -name '*.rpm' -print | sort)
[ "${#available_rpms[@]}" -gt 0 ] || {
    echo "ERROR: no RPM packages found in $BUNDLE" >&2
    exit 1
}

for package in "${available_rpms[@]}"; do
    package_name=$(rpm -qp --qf '%{NAME}' "$package")
    package_evr=$(rpm -qp --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package")
    package_arch=$(rpm -qp --qf '%{ARCH}' "$package")
    [ "$package_evr" = "$HOTFIX_EVR" ] || {
        echo "ERROR: package $package_name has unexpected version $package_evr" >&2
        exit 1
    }
    case "$package_arch" in
        noarch|"$host_arch") ;;
        *) echo "ERROR: package $package_name architecture $package_arch does not match $host_arch" >&2; exit 1 ;;
    esac
    [ -z "${bundle_by_name[$package_name]:-}" ] || {
        echo "ERROR: duplicate package $package_name in bundle" >&2
        exit 1
    }
    bundle_by_name[$package_name]=$package
done

mapfile -t installed_names < <(rpm -qa --qf '%{NAME}\n' 'nginx*' | sort -u)
printf '%s\n' "${installed_names[@]}" | grep -qx nginx || {
    echo "ERROR: the $TARGET_NAME NGINX $TARGET_STREAM package family is not installed" >&2
    exit 1
}

selected_rpms=()
for package_name in "${installed_names[@]}"; do
    package_evr=$(rpm -q --qf '%{EPOCHNUM}:%{VERSION}-%{RELEASE}' "$package_name")
    case "$package_evr" in
        "$BASE_EVR"|"$HOTFIX_EVR") ;;
        *) echo "ERROR: installed $package_name version $package_evr does not match this bundle" >&2; exit 1 ;;
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

dnf -y install "${selected_rpms[@]}"
nginx -t

if [ "$was_active" -eq 1 ]; then
    systemctl is-active --quiet nginx || {
        echo 'ERROR: nginx was active before the upgrade but is not active now' >&2
        exit 1
    }
fi

echo "PASS: upgraded installed $TARGET_NAME 9 NGINX $TARGET_STREAM packages to $HOTFIX_EVR"
rpm -q --qf '%{NAME} %{EPOCHNUM}:%{VERSION}-%{RELEASE}\n' "${installed_names[@]}" | sort
