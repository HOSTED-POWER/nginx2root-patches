#!/bin/bash
# Verify the security-sensitive source semantics after all quilt patches are applied.
set -euo pipefail
SOURCE=$(realpath "$1")
RELEASE=$2
HTTP2_REUSE_REQUIRED=${3:-1}
SMTP_READ_GUARD_REQUIRED=${4:-0}
REQUEST_BODY_AGAIN_REQUIRED=${5:-0}
TRY_FILES_REQUIRED=${6:-0}
SSL_PREREAD_REQUIRED=${7:-0}
STREAM_SNI_VERIFY_REQUIRED=${8:-0}
BOOKWORM_BASELINE_REQUIRED=${9:-0}
RAPID_RESET_REQUIRED=${10:-0}

assert_contains() {
    local file=$1 expression=$2 description=$3
    grep -qF "$expression" "$SOURCE/$file" || {
        echo "missing security condition: $description" >&2
        exit 1
    }
}

assert_contains_any() {
    local file=$1 description=$2
    shift 2
    local expression
    for expression in "$@"; do
        if grep -qF "$expression" "$SOURCE/$file"; then
            return 0
        fi
    done
    echo "missing security condition: $description" >&2
    exit 1
}

if [ "$RELEASE" -ge 9 ]; then
    assert_contains_any src/http/v2/ngx_http_v2.c \
        'HTTP/2 queued-byte window calculation' \
        'send_window = h2c->send_window' \
        'send_window = h2c->send_window + ngx_http_v2_private(h2c)->send_queued;'
    assert_contains_any src/http/v2/ngx_http_v2.c \
        'HTTP/2 queued-byte accounting' \
        '+ ngx_http_v2_connection_private(h2c)->send_queued;' \
        '+ ngx_http_v2_private(h2c)->send_queued;'
    assert_contains src/http/v2/ngx_http_v2.c \
        'h2c = &h2p->connection;' 'HTTP/2 private connection allocation'
    assert_contains_any src/http/v2/ngx_http_v2_filter_module.c \
        'HTTP/2 queue increment' \
        'ngx_http_v2_connection_private(h2c)->send_queued += frame_size;' \
        'ngx_http_v2_private(h2c)->send_queued += frame_size;'
    assert_contains_any src/http/v2/ngx_http_v2_filter_module.c \
        'HTTP/2 queue decrement' \
        'ngx_http_v2_connection_private(h2c)->send_queued -= frame->length;' \
        'ngx_http_v2_private(h2c)->send_queued -= frame->length;'
    if grep -qF 'if (window > NGX_HTTP_V2_MAX_WINDOW - h2c->send_window)' \
        "$SOURCE/src/http/v2/ngx_http_v2.c"; then
        echo 'vulnerable CVE-2026-123007 flow-control condition remains' >&2
        exit 1
    fi

    if [ "$HTTP2_REUSE_REQUIRED" -eq 1 ]; then
        assert_contains src/http/v2/ngx_http_v2.c \
            'ngx_reusable_connection(h2c->connection, 0);' 'HTTP/2 active-connection reuse guard'
    fi
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

if [ "$RELEASE" -le 10 ] || [ "$SMTP_READ_GUARD_REQUIRED" -eq 1 ]; then
    assert_contains src/mail/ngx_mail_smtp_handler.c \
        'ngx_mail_smtp_block_reading(ngx_event_t *rev)' 'SMTP resolver read prerequisite'
fi

if [ "$RELEASE" = 13 ]; then
    assert_contains src/event/quic/ngx_event_quic_streams.c \
        'ngx_rbtree_insert(&qc->streams.tree, &qs->node);' 'QUIC early stream registration'
fi

if [ "$REQUEST_BODY_AGAIN_REQUIRED" -eq 1 ]; then
    assert_contains src/http/ngx_http_request_body.c \
        'n = NGX_AGAIN;' 'request body initial NGX_AGAIN state'
    assert_contains_any src/http/ngx_http_request_body.c \
        'request body NGX_AGAIN handling' \
        'if (n == NGX_AGAIN || !c->read->ready || rb->rest == 0)' \
        'if (n == NGX_AGAIN || !c->read->ready)'
fi

if [ "$TRY_FILES_REQUIRED" -eq 1 ]; then
    if [ -f "$SOURCE/src/http/modules/ngx_http_try_files_module.c" ]; then
        assert_contains src/http/modules/ngx_http_try_files_module.c \
            'len = e.pos - name + 1;' 'try_files generated path length restoration'
    else
        assert_contains src/http/ngx_http_core_module.c \
            'len = e.pos - name + 1;' 'legacy try_files generated path length restoration'
    fi
fi

if [ "$SSL_PREREAD_REQUIRED" -ge 1 ]; then
    assert_contains src/stream/ngx_stream_ssl_preread_module.c \
        'ssl preread: extensions length error' 'ssl_preread extension block length validation'
    assert_contains src/stream/ngx_stream_ssl_preread_module.c \
        'ssl preread: duplicate SNI' 'ssl_preread duplicate SNI rejection'
    assert_contains src/stream/ngx_stream_ssl_preread_module.c \
        'ssl preread: duplicate ALPN' 'ssl_preread duplicate ALPN rejection'
    assert_contains src/stream/ngx_stream_ssl_preread_module.c \
        'ssl preread: SNI format error' 'ssl_preread SNI length validation'
    assert_contains src/stream/ngx_stream_ssl_preread_module.c \
        'ssl preread: ALPN format error' 'ssl_preread ALPN length validation'
fi

if [ "$SSL_PREREAD_REQUIRED" -ge 2 ]; then
    assert_contains src/stream/ngx_stream_ssl_preread_module.c \
        'ssl preread: supported_versions format error' \
        'ssl_preread supported_versions length validation'
fi

if [ "$STREAM_SNI_VERIFY_REQUIRED" -eq 1 ]; then
    assert_contains src/stream/ngx_stream_ssl_module.c \
        'sscf = ngx_stream_get_module_srv_conf(s, ngx_stream_ssl_module);' \
        'stream SNI-selected client certificate configuration refresh'
fi

if [ "$BOOKWORM_BASELINE_REQUIRED" -eq 1 ]; then
    assert_contains src/http/ngx_http_core_module.c \
        'if (alias && (!r->valid_location || r->uri_changed))' \
        'post-rewrite alias path mapping rejection'
    assert_contains src/http/ngx_http_script.c \
        'e.buf.len = n;' 'HTTP script reserved memory accounting'
    assert_contains src/stream/ngx_stream_script.c \
        'e.buf.len = n;' 'stream script reserved memory accounting'
    assert_contains src/http/ngx_http_request.hh \
        '#define NGX_HTTP_MAX_BLOCKED               250' \
        'pending request operation limit'
    assert_contains src/http/ngx_http_file_cache.c \
        'if (r->main->blocked >= NGX_HTTP_MAX_BLOCKED)' \
        'file-cache pending operation guard'
fi

if [ "$RAPID_RESET_REQUIRED" -eq 1 ]; then
    assert_contains src/http/v2/ngx_http_v2.c \
        'if (h2p->new_streams++ >= 2 * h2scf->concurrent_streams)' \
        'HTTP/2 per-iteration stream creation limit'
    assert_contains src/http/v2/ngx_http_v2.c \
        'if (h2p->refused_streams++ > ngx_max(h2scf->concurrent_streams, 100))' \
        'HTTP/2 refused stream limit'
fi

echo 'PASS: source contains every required security condition'
