#!/bin/sh
set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/owntone-render.XXXXXX")
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

render() {
    name=$1
    options=$2
    mkdir -p "$TMP/$name/persist"
    RENDER_LIB_DIR="$ROOT" "$ROOT/render-config.sh" \
        "$options" "$TMP/$name/owntone.conf" "$TMP/$name/shairport.conf" \
        "$TMP/$name/persist"
}

ruby -ryaml -rjson -e \
    'puts JSON.pretty_generate(YAML.safe_load_file(ARGV.fetch(0)).fetch("options"))' \
    "$ROOT/config.yaml" > "$TMP/default.json"

render default "$TMP/default.json"
grep -F 'db_path = "/share/owntone/dbase_and_logs/songs3.db"' "$TMP/default/owntone.conf" >/dev/null
grep -F 'pipe_sample_rate = 44100' "$TMP/default/owntone.conf" >/dev/null
grep -F 'pipe_bits_per_sample = 16' "$TMP/default/owntone.conf" >/dev/null
grep -F 'ignore_volume_control = "yes";' "$TMP/default/shairport.conf" >/dev/null
grep -F 'output_rate = 44100;' "$TMP/default/shairport.conf" >/dev/null
grep -F 'output_format = "S16_LE";' "$TMP/default/shairport.conf" >/dev/null
grep -F 'output_channels = 2;' "$TMP/default/shairport.conf" >/dev/null
if grep -F 'metadata = {' "$TMP/default/shairport.conf" >/dev/null; then
    echo "metadata section rendered while disabled" >&2
    exit 1
fi

jq '.streaming.bit_rate="192" | .shairport.pipe_sample_rate="44100"' \
    "$TMP/default.json" > "$TMP/supervisor-coercion.json"
render supervisor-coercion "$TMP/supervisor-coercion.json"
grep -F 'bit_rate = 192' "$TMP/supervisor-coercion/owntone.conf" >/dev/null
if grep -F 'bit_rate = "192"' "$TMP/supervisor-coercion/owntone.conf" >/dev/null; then
    echo "numeric streaming bit rate rendered as a string" >&2
    exit 1
fi

render all "$ROOT/tests/fixtures/all-options.json"
grep -F 'pipe_sample_rate = 96000' "$TMP/all/owntone.conf" >/dev/null
grep -F 'pipe_bits_per_sample = 32' "$TMP/all/owntone.conf" >/dev/null
grep -F 'ignore_volume_control = "no";' "$TMP/all/shairport.conf" >/dev/null
grep -F 'metadata = {' "$TMP/all/shairport.conf" >/dev/null
grep -F 'name = "Multiroom \"Test\"";' "$TMP/all/shairport.conf" >/dev/null
grep -F 'airplay "Speaker \"One\"" {' "$TMP/all/owntone.conf" >/dev/null

for rate in 44100 48000 88200 96000; do
    for format in S16_LE S32_LE; do
        jq --argjson rate "$rate" --arg format "$format" \
            '.shairport.pipe_sample_rate=$rate | .shairport.pipe_sample_format=$format' \
            "$TMP/default.json" > "$TMP/pair.json"
        render "pair-$rate-$format" "$TMP/pair.json"
        bits=16
        [ "$format" = S32_LE ] && bits=32
        grep -F "pipe_sample_rate = $rate" "$TMP/pair-$rate-$format/owntone.conf" >/dev/null
        grep -F "pipe_bits_per_sample = $bits" "$TMP/pair-$rate-$format/owntone.conf" >/dev/null
        grep -F "output_rate = $rate;" "$TMP/pair-$rate-$format/shairport.conf" >/dev/null
        grep -F "output_format = \"$format\";" "$TMP/pair-$rate-$format/shairport.conf" >/dev/null
    done
done

for metadata in true false; do
    for ignore in true false; do
        jq --argjson metadata "$metadata" --argjson ignore "$ignore" \
            '.shairport.metadata_enabled=$metadata | .shairport.ignore_volume_control=$ignore' \
            "$TMP/default.json" > "$TMP/volume.json"
        render "volume-$metadata-$ignore" "$TMP/volume.json"
        expected=no
        [ "$ignore" = true ] && expected=yes
        grep -F "ignore_volume_control = \"$expected\";" \
            "$TMP/volume-$metadata-$ignore/shairport.conf" >/dev/null
        if [ "$metadata" = true ]; then
            grep -F 'metadata = {' "$TMP/volume-$metadata-$ignore/shairport.conf" >/dev/null
        elif grep -F 'metadata = {' "$TMP/volume-$metadata-$ignore/shairport.conf" >/dev/null; then
            echo "metadata section rendered while disabled" >&2
            exit 1
        fi
    done
done

for bad_rate in 0 32000 192000 invalid; do
    jq --arg rate "$bad_rate" '.shairport.pipe_sample_rate=$rate' "$TMP/default.json" > "$TMP/bad.json"
    if render bad "$TMP/bad.json" 2>/dev/null; then
        echo "invalid sample rate accepted: $bad_rate" >&2
        exit 1
    fi
done

for bad_format in S24_LE auto invalid; do
    jq --arg format "$bad_format" '.shairport.pipe_sample_format=$format' "$TMP/default.json" > "$TMP/bad.json"
    if render bad "$TMP/bad.json" 2>/dev/null; then
        echo "invalid sample format accepted: $bad_format" >&2
        exit 1
    fi
done

for bad_override in output_channels output_backend pipe_name; do
    jq --arg field "$bad_override" '.shairport[$field]="unsupported"' \
        "$TMP/default.json" > "$TMP/bad.json"
    if render bad "$TMP/bad.json" 2>/dev/null; then
        echo "App-controlled Shairport option accepted: $bad_override" >&2
        exit 1
    fi
done

for malformed in 'null' '[]' '"yes"'; do
    jq --argjson value "$malformed" '.shairport.ignore_volume_control=$value' \
        "$TMP/default.json" > "$TMP/bad.json"
    if render bad "$TMP/bad.json" 2>/dev/null; then
        echo "malformed ignore_volume_control accepted: $malformed" >&2
        exit 1
    fi
done

echo "Renderer tests passed"
