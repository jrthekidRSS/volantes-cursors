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
readonly DISPLAY_NAME="Volantes Cursors"

read -r -d '' HYPRCURSORS_MANIFEST_CONTENTS <<- EOF
name = $DISPLAY_NAME
description = Design by varlesh
cursors_directory = hyprcursors
EOF

read -r -d '' META_HL_FORMAT <<- EOF
hotspot_x = %s
hotspot_y = %s

%s
%s
EOF

read -r -d '' META_HL_LINE_FORMAT <<- EOF
define_size = %s, %s
EOF

read -r -d '' META_HL_OVERRIDES_FORMAT <<- EOF
define_override = %s
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
    readarray -t svg_files < <(ls -m1 "$SRC_DIR/volantes_cursors")
    printf '%s' "$HYPRCURSORS_MANIFEST_CONTENTS" > "$INTERMEDIATE_DIR/manifest.hl"
    set +e
    local cursors_output="$INTERMEDIATE_DIR/hyprcursors"
    mkdir "$cursors_output"

    for svg_file in "${svg_files[@]}"; do
        if [[ "$svg_file" != *.svg ]] || [[ "$svg_file" == *_24.svg ]]; then
            continue
        fi

        local cursor_name="${svg_file::-4}"

        [[ "$cursor_name" =~ -[[:digit:]]{2}$ ]] && cursor_name="${cursor_name::-3}"

        local output_contents= hotspot_x= hotspot_y= overrides_contents=
        read -r _ hotspot_x hotspot_y _ < "$SRC_DIR/config/$cursor_name.cursor"

        # Read cursor's config file
        while IFS= read -r line; do
            read -r size nan nan xcursor_filename animation <<< "$line"

            [[ -n "$size" ]] || continue

            # Animated cursors are made up of files with slightly different
            # names between each other
            local cursor_file="$svg_file"
            #IFS='_' read -r cursor_frame _ <<< "$xcursor_filename"
            cursor_frame="${xcursor_filename//_[0-9][0-9]/}"
            cursor_frame="${cursor_frame/.png/}"

            if [[ "$cursor_frame" != "$cursor_name" ]]; then
                cursor_file="${cursor_frame}.svg"
            fi

            meta_hl_line="$(printf "$META_HL_LINE_FORMAT" "$size" "$cursor_file")"

            if [[ -n "$animation" ]]; then
                meta_hl_line="${meta_hl_line}, $animation"
            fi

            # `${IFS:2:1}` is '\n'
            output_contents="${output_contents}${meta_hl_line}${IFS:2:1}"
        done < "$SRC_DIR/config/$cursor_name.cursor"

        while read -r override _; do
            if [[ -n "$override" ]]; then
                overrides_contents="${overrides_contents}$(printf "\n${META_HL_OVERRIDES_FORMAT}" "$override")"
            fi
        done < <(grep --color=never "$cursor_name$" "$SRC_DIR/cursorList" 2>/dev/null)

        hotspot_x="0$(bc <<< "scale=16; $hotspot_x / 32")"
        hotspot_y="0$(bc <<< "scale=16; $hotspot_y / 32")"

        local meta_hl_contents="$(printf "$META_HL_FORMAT" "$hotspot_x" "$hotspot_y" "$output_contents" "$overrides_contents" )"
        mkdir -p "$cursors_output/$cursor_name" 2>/dev/null
        echo -n "$meta_hl_contents" > "$cursors_output/$cursor_name/meta.hl"
        cp "$SRC_DIR/volantes_cursors/$cursor_name"* "$cursors_output/$cursor_name"
    done

    mkdir -p "$INTERMEDIATE_DIR/build"
    hyprcursor-util --create "$INTERMEDIATE_DIR" --output "$INTERMEDIATE_DIR/build" 1>/dev/null
    sleep 1000
    exit 0
}

gen-xcursors() {
    echo
}

parse-flags() {
    local flags="$1"
    local value="$2"
    local flags_count=$(( ${#flags} - 1 ))

    for (( i=1; i < ${#flags}; i++)); do
        # Get the current letter
        local arg="${flags:$i:1}"

        case "$arg" in
            h)
                print-help
                exit 0
                ;;
            *)
                printf "error: invalid parameter '-%s'\n%s\n" \
                "$arg" "$(print-help)" 1>&2

                exit 2
                ;;
        esac
    done
}

while (( $# > 0 )); do
    case "$1" in
        --help)
            parse-flags '-h'
            ;;
        -*)
            parse-flags "$1" "$2"
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

gen-hyprcursors
