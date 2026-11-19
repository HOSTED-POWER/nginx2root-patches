#!/bin/bash
# Verify the security-sensitive source semantics after all quilt patches are applied.
set -euo pipefail
SOURCE=$(realpath "$1")
RELEASE=$2

assert_contains() {
    local file=$1 expression=$2 description=$3
    grep -qF "$expression" "$SOURCE/$file" || {
        echo "missing security condition: $description" >&2
        exit 1
    }
}

if [ "$RELEASE" -ge 9 ]; then
    assert_contains src/http/v2/ngx_http_v2.c \
        'send_window = h2c->send_window' 'HTTP/2 queued-byte window calculation'
    assert_contains src/http/v2/ngx_http_v2.c \
        '+ ngx_http_v2_connection_private(h2c)->send_queued;' 'HTTP/2 queued-byte accounting'
    assert_contains src/http/v2/ngx_http_v2.c \
        'h2c = &h2p->connection;' 'HTTP/2 private connection allocation'
    assert_contains src/http/v2/ngx_http_v2_filter_module.c \
        'ngx_http_v2_connection_private(h2c)->send_queued += frame_size;' 'HTTP/2 queue increment'
    assert_contains src/http/v2/ngx_http_v2_filter_module.c \
        'ngx_http_v2_connection_private(h2c)->send_queued -= frame->length;' 'HTTP/2 queue decrement'
    if grep -qF 'if (window > NGX_HTTP_V2_MAX_WINDOW - h2c->send_window)' \
        "$SOURCE/src/http/v2/ngx_http_v2.c"; then
        echo 'vulnerable CVE-2026-123007 flow-control condition remains' >&2
        exit 1
    fi

    assert_contains src/http/v2/ngx_http_v2.c \
        'ngx_reusable_connection(h2c->connection, 0);' 'HTTP/2 active-connection reuse guard'
fi
assert_contains src/core/ngx_resolver.c \
    'ngx_resolver_free_handler(ngx_resolver_ctx_t *ctx)' 'resolver deferred-free handler'
assert_contains src/core/ngx_resolver.c \
    'ctx->handler = ngx_resolver_free_handler;' 'resolver detached-context handler'
assert_contains src/core/ngx_resolver.c \
    'ctx->handler != ngx_resolver_free_handler' 'resolver deferred cleanup guard'
assert_contains src/core/ngx_resolver.c \
    'if (ngx_resolve_name_locked(r, ctx, &name) == NGX_ERROR)' 'resolver CNAME restart error handling'
assert_contains src/mail/ngx_mail_auth_http_module.c \
    'ngx_mail_auth_http_block_write(ngx_event_t *wev)' 'mail asynchronous write guard'
assert_contains src/mail/ngx_mail_proxy_module.c \
    's->connection->write->handler = ngx_mail_proxy_block_write;' 'mail proxy client write guard'
assert_contains src/mail/ngx_mail_smtp_handler.c \
    'ngx_mail_smtp_block_writing(ngx_event_t *wev)' 'SMTP resolver write guard'

if [ "$RELEASE" -le 10 ]; then
    assert_contains src/mail/ngx_mail_smtp_handler.c \
        'ngx_mail_smtp_block_reading(ngx_event_t *rev)' 'SMTP resolver read prerequisite'
fi

if [ "$RELEASE" = 13 ]; then
    assert_contains src/event/quic/ngx_event_quic_streams.c \
        'ngx_rbtree_insert(&qc->streams.tree, &qs->node);' 'QUIC early stream registration'
fi

echo "PASS: Debian $RELEASE source contains every required security condition"
