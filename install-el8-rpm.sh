#!/bin/bash
set -euo pipefail

ROOT=$(dirname "$(realpath "$0")")
exec "$ROOT/install-el9-rpm.sh" "$@"
