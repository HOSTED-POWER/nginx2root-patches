#!/bin/bash
set -euo pipefail

keyring=
signature=
data=
for argument in "$@"; do
    case "$argument" in
        --keyring=*) keyring=${argument#*=} ;;
        --signature=*) signature=${argument#*=} ;;
        --data=*) data=${argument#*=} ;;
        *) echo "unsupported gpgverify argument: $argument" >&2; exit 1 ;;
    esac
done

[ -n "$keyring" ] && [ -n "$signature" ] && [ -n "$data" ] || {
    echo 'gpgverify requires --keyring, --signature and --data' >&2
    exit 1
}

gnupg_home=$(mktemp -d)
trap 'rm -rf "$gnupg_home"' EXIT
chmod 0700 "$gnupg_home"
gpg2 --batch --homedir "$gnupg_home" --import "$keyring" >/dev/null 2>&1
gpgv2 --keyring "$gnupg_home/pubring.gpg" "$signature" "$data"
