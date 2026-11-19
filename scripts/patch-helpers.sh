#!/bin/bash

strip_patch_hunk() {
    local patch_file=$1 marker=$2 temporary
    temporary="$patch_file.tmp"
    grep -qF "$marker" "$patch_file" || {
        echo "patch context changed: $marker" >&2
        exit 1
    }
    awk -v marker="$marker" '
        $0 == marker { skip=1; next }
        skip && /^@@ / { skip=0 }
        !skip { print }
    ' "$patch_file" > "$temporary"
    mv "$temporary" "$patch_file"
}
