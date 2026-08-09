#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)

ruby "$ROOT/tests/audit-config.rb"
if [ -n "${OWNTONE_UPSTREAM_TEMPLATE:-}" ]; then
    "$ROOT/tests/audit-upstream.sh" "$OWNTONE_UPSTREAM_TEMPLATE"
fi
shellcheck "$ROOT/render-config.sh" "$ROOT/owntone-config.init" \
    "$ROOT/shairport-sync.init" "$ROOT/tests/test-renderer.sh"
"$ROOT/tests/test-renderer.sh"
echo "All tests passed"
