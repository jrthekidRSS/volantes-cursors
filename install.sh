#!/usr/bin/env bash

readonly USER_ID="$(id -u)"

if [[ "$USER_ID" == 0 ]]; then
    readonly OUTPUT_DIR="/usr/share/icons"
else
    readonly OUTPUT_DIR="$HOME/.local/share/icons"
fi

readonly OUTPUT_NAME="volantes_cursors"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$0")"
readonly SRC_DIR="$(dirname -- "$0")/src"
readonly INTERMEDIATE_DIR="/tmp/$USER_ID-$OUTPUT_NAME"

read -r -d '' HYPRCURSORS_MANIFEST_CONTENTS <<- EOF
name = Volantes Cursors
description = Design by varlesh
cursors_directory = hyprcursors
EOF

cleanup() {
    rm -r "$INTERMEDIATE_DIR" 2>/dev/null
}

print-help() {
cat <<- EOF
Usage: $SCRIPT_NAME [-ch]
EOF
}

gen-hyprcursors() {
    set -e

    readarray -t svg_files < <(ls -m1 "$SRC_DIR")
    printf '%s' "$HYPRCURSORS_MANIFEST_CONTENTS" > "$INTERMEDIATE_DIR/manifest.hl"
    local cursors_output="$INTERMEDIATE_DIR/hyprcursors"
    mkdir "$cursors_output"

    for svg_file in "${svg_files[@]}"; do
        if [[ "$svg_file" == *.svg ]] && [[ ! "$svg_file" == *_24.svg ]]; then
            local output_file="${svg_file::-4}"

            [[ "$output_file" =~ -[[:digit:]]{2}$ ]] && output_file="${output_file::-3}"
        fi
    done
}

gen-xcursors() {
    #
}

while (( $# > 0 )); do
    case "$1" in
        -h|--help)
            print-help
            exit 0
            ;;
        *)
            printf "error: invalid parameter '%s'\n%s\n" "$1" "$(print-help)" 1>&2
    esac

    shift
done

trap cleanup EXIT

if [[ -d "$INTERMEDIATE_DIR" ]]; then
    [[ "$INTERMEDIATE" != '/' ]] && rm -r "$INTERMEDIATE_DIR"/*
else
    mkdir "$INTERMEDIATE_DIR"
fi

gen-xcursors
