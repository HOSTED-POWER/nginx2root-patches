#!/bin/bash

configure_legacy_apt() {
    local release=$1 codename=$2 key_source key_target

    [ "$release" -le 11 ] || return 0

    key_source="$ROOT/keys/freexian-archive-key.asc"
    key_target=/usr/share/keyrings/freexian-archive-key.asc
    printf '%s  %s\n' \
        'eedd870262a87eb8fc950090b69ce082c24a0c63d3c227636a6cdc864dd18d8f' \
        "$key_source" | sha256sum --check --status || {
        echo 'Freexian archive key checksum mismatch' >&2
        exit 1
    }
    cp "$key_source" "$key_target"
    printf 'deb [signed-by=%s] http://deb.freexian.com/extended-lts %s main contrib non-free\n' \
        "$key_target" "$codename" > /etc/apt/sources.list
}
