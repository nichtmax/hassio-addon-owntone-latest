#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
TEMPLATE=${1:-}

if [ -n "$TEMPLATE" ]; then
    exec ruby "$ROOT/tests/audit-upstream.rb" "$TEMPLATE"
fi

TMP=$(mktemp "${TMPDIR:-/tmp}/owntone-conf.XXXXXX")
trap 'rm -f "$TMP"' EXIT HUP INT TERM
curl -fsSL \
    https://raw.githubusercontent.com/owntone/owntone-server/refs/heads/master/owntone.conf.in \
    -o "$TMP"
ruby "$ROOT/tests/audit-upstream.rb" "$TMP"
