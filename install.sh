#!/bin/bash
# Upgrade only NGINX packages that are already installed and present in this bundle.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || {
    echo 'ERROR: run as root (sudo ./install.sh)' >&2
    exit 1
}

BUNDLE=$(realpath "${1:-$(dirname "$0")}")
. /etc/os-release

mapfile -t available_debs < <(find "$BUNDLE" -maxdepth 1 -type f -name '*.deb' -print | sort)
[ "${#available_debs[@]}" -gt 0 ] || {
    echo "ERROR: no .deb packages found in $BUNDLE" >&2
    exit 1
}

nginx_deb=$(find "$BUNDLE" -maxdepth 1 -type f -name 'nginx_*.deb' -print -quit)
[ -n "$nginx_deb" ] || {
    echo 'ERROR: bundle has no nginx binary package' >&2
    exit 1
}

nginx_version=$(dpkg-deb -f "$nginx_deb" Version)
nginx_architecture=$(dpkg-deb -f "$nginx_deb" Architecture)
case "$nginx_version" in
    *+deb"$VERSION_ID"u*~hp*) ;;
    *)
        echo "ERROR: package $nginx_version does not match Debian $VERSION_ID" >&2
        exit 1
        ;;
esac
[ "$nginx_architecture" = "$(dpkg --print-architecture)" ] || {
    echo "ERROR: package architecture $nginx_architecture does not match $(dpkg --print-architecture)" >&2
    exit 1
}

selected_debs=()
selected_names=()
for deb in "${available_debs[@]}"; do
    package_name=$(dpkg-deb -f "$deb" Package)
    package_status=$(dpkg-query -W -f='${db:Status-Status}' "$package_name" 2>/dev/null || true)
    if [ "$package_status" = installed ]; then
        selected_debs+=("$deb")
        selected_names+=("$package_name")
    fi
done

printf '%s\n' "${selected_names[@]}" | grep -qx nginx || {
    echo 'ERROR: nginx is not installed on this host' >&2
    exit 1
}

nginx -t
was_active=0
if [ -d /run/systemd/system ] && systemctl is-active --quiet nginx; then
    was_active=1
fi

apt-get install -y --no-install-recommends "${selected_debs[@]}"
nginx -t

if [ "$was_active" -eq 1 ]; then
    systemctl is-active --quiet nginx || {
        echo 'ERROR: nginx was active before the upgrade but is not active now' >&2
        exit 1
    }
fi

echo "PASS: upgraded installed NGINX packages to $nginx_version"
dpkg-query -W -f='${binary:Package} ${Version}\n' "${selected_names[@]}" | sort
