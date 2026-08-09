#!/bin/sh
# Render OwnTone and Shairport Sync configuration from Home Assistant options.
set -eu

OPTIONS_PATH=${1:-/data/options.json}
OWNTONE_OUTPUT=${2:-/etc/owntone/owntone.conf}
SHAIRPORT_OUTPUT=${3:-/etc/shairport-sync.conf}
PERSIST_DIR=${4:-/share/owntone/dbase_and_logs}
RENDER_LIB_DIR=${RENDER_LIB_DIR:-/usr/local/lib/owntone-addon}

fail() {
    echo "Configuration error: $*" >&2
    exit 1
}

[ -r "$OPTIONS_PATH" ] || fail "cannot read $OPTIONS_PATH"
jq -e 'type == "object"' "$OPTIONS_PATH" >/dev/null || fail "options must be a JSON object"
jq -e '(.shairport // {}) | type == "object"' "$OPTIONS_PATH" >/dev/null || \
    fail "shairport must be an object"

if ! jq -e '
    ((.shairport // {}) | keys - [
      "name", "password", "metadata_enabled", "ignore_volume_control",
      "allow_session_interruption", "session_timeout",
      "pipe_sample_rate", "pipe_sample_format"
    ]) == []
' "$OPTIONS_PATH" >/dev/null; then
    fail "shairport contains unsupported options; backend, pipe path, and channels are App-controlled"
fi

for field in name password pipe_sample_format; do
    if jq -e --arg field "$field" \
        '(.shairport | has($field)) and (.shairport[$field] | type != "string")' \
        "$OPTIONS_PATH" >/dev/null; then
        fail "shairport.$field must be a string"
    fi
done

PIPE_RATE=$(jq -r '.shairport.pipe_sample_rate // 44100' "$OPTIONS_PATH")
case "$PIPE_RATE" in
    44100|48000|88200|96000) ;;
    *) fail "shairport.pipe_sample_rate must be 44100, 48000, 88200, or 96000" ;;
esac

PIPE_FORMAT=$(jq -r '.shairport.pipe_sample_format // "S16_LE"' "$OPTIONS_PATH")
case "$PIPE_FORMAT" in
    S16_LE|S32_LE) ;;
    *) fail "shairport.pipe_sample_format must be S16_LE or S32_LE" ;;
esac

for field in metadata_enabled ignore_volume_control allow_session_interruption; do
    if jq -e --arg field "$field" \
        '(.shairport | has($field)) and (.shairport[$field] | type != "boolean")' \
        "$OPTIONS_PATH" >/dev/null; then
        fail "shairport.$field must be a boolean"
    fi
done

if jq -e '
    (.shairport | has("session_timeout")) and
    (((.shairport.session_timeout | type) != "number") or
     ((.shairport.session_timeout | floor) != .shairport.session_timeout))
' "$OPTIONS_PATH" >/dev/null; then
    fail "shairport.session_timeout must be an integer of at least 60 seconds"
fi

SESSION_TIMEOUT=$(jq -r '.shairport.session_timeout // 60' "$OPTIONS_PATH")
case "$SESSION_TIMEOUT" in
    ''|*[!0-9]*) fail "shairport.session_timeout must be an integer of at least 60 seconds" ;;
esac
[ "$SESSION_TIMEOUT" -ge 60 ] || \
    fail "shairport.session_timeout must be an integer of at least 60 seconds"

mkdir -p "$(dirname "$OWNTONE_OUTPUT")" "$(dirname "$SHAIRPORT_OUTPUT")" "$PERSIST_DIR"
OWNTONE_TMP="${OWNTONE_OUTPUT}.tmp"
SHAIRPORT_TMP="${SHAIRPORT_OUTPUT}.tmp"
trap 'rm -f "$OWNTONE_TMP" "$SHAIRPORT_TMP"' EXIT HUP INT TERM

jq -r -f "$RENDER_LIB_DIR/render-owntone.jq" "$OPTIONS_PATH" > "$OWNTONE_TMP"
jq -r -f "$RENDER_LIB_DIR/render-shairport.jq" "$OPTIONS_PATH" > "$SHAIRPORT_TMP"

chmod 640 "$OWNTONE_TMP" "$SHAIRPORT_TMP"
mv "$OWNTONE_TMP" "$OWNTONE_OUTPUT"
mv "$SHAIRPORT_TMP" "$SHAIRPORT_OUTPUT"

# Diagnostic copies only. They are overwritten on every start and never read
# back, so Home Assistant options remain the sole source of truth.
cp "$OWNTONE_OUTPUT" "$PERSIST_DIR/owntone.conf"
cp "$SHAIRPORT_OUTPUT" "$PERSIST_DIR/shairport-sync.conf"

trap - EXIT HUP INT TERM
