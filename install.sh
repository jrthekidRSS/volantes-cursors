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
readonly WORKING_DIR="/tmp/$USER_ID-$OUTPUT_NAME"
readonly WORKING_SRC_DIR="$WORKING_DIR/src"
readonly OUTPUT_DISPLAY_NAME="Volantes Cursors"

read -r -d '' HYPRCURSORS_MANIFEST_CONTENTS <<- EOF
name = $OUTPUT_DISPLAY_NAME
description = Design by varlesh
cursors_directory = hyprcursors
EOF

read -r -d '' META_HL_FORMAT <<- EOF
hotspot_x = %s
hotspot_y = %s

%s
%s
EOF

read -r -d '' META_HL_SIZE_FORMAT <<- EOF
define_size = %s, %s
EOF

read -r -d '' META_HL_OVERRIDES_FORMAT <<- EOF
define_override = %s
EOF

cleanup() {
    rm -r "$WORKING_DIR" 2>/dev/null
}

print-help() {
cat <<- EOF
Usage: $SCRIPT_NAME [-ch]
EOF
}

gen-hyprcursors() {
    set -e
    readarray -t svg_files < <(ls -m1 "$WORKING_SRC_DIR/volantes_cursors")
    printf '%s' "$HYPRCURSORS_MANIFEST_CONTENTS" > "$WORKING_DIR/manifest.hl"
    set +e
    local cursors_output="$WORKING_DIR/hyprcursors"
    mkdir "$cursors_output"

    for svg_file in "${svg_files[@]}"; do
        if [[ "$svg_file" != *.svg ]] || [[ "$svg_file" == *_24.svg ]]; then
            continue
        fi

        # Trim '.svg' off of end
        local cursor_name="${svg_file::-4}"

        if [[ "$cursor_name" =~ -[[:digit:]]{2} ]]; then
            # Skip parsing extra frames of animations
            [[ "$cursor_name" == *"-01"* ]] || continue

            # Trim '-01' off of end for animations
            cursor_name="${cursor_name::-3}"
        fi

        local output_contents= hotspot_x= hotspot_y= overrides_contents=
        read -r _ hotspot_x hotspot_y _ < "$WORKING_SRC_DIR/config/$cursor_name.cursor"

        # Read cursor's config file
        while IFS= read -r line; do
            read -r size _ _ xcursor_filename animation <<< "$line"

            if [[ -z "$size" ]] || (( $size > 32 )); then
                continue
            fi

            # Animated cursors are made up of files with slightly different
            # names between each other
            local cursor_file="$svg_file"
            cursor_frame="${xcursor_filename/_[0-9][0-9].png/}"

            if [[ "$cursor_frame" != "$cursor_name" ]]; then
                cursor_file="${cursor_frame}.svg"
            fi

            # define_size = SIZE, IMAGE
            meta_hl_size="$(printf "$META_HL_SIZE_FORMAT" "$size" "$cursor_file")"

            # Animation field of define_size if it exists
            if [[ -n "$animation" ]]; then
                meta_hl_size="${meta_hl_size}, $animation"
            fi

            # `${IFS:2:1}` is '\n'
            output_contents="${output_contents}${meta_hl_size}${IFS:2:1}"
        done < "$WORKING_SRC_DIR/config/$cursor_name.cursor"

        while read -r override _; do
            if [[ -n "$override" ]]; then
                overrides_contents="${overrides_contents}$(printf "\n${META_HL_OVERRIDES_FORMAT}" "$override")"
            fi
        done < <(grep --color=never "$cursor_name$" "$WORKING_SRC_DIR/cursorList" 2>/dev/null)

        hotspot_x="0$(bc <<< "scale=16; $hotspot_x / 32")"
        hotspot_y="0$(bc <<< "scale=16; $hotspot_y / 32")"

        local meta_hl_contents="$(printf "$META_HL_FORMAT" "$hotspot_x" "$hotspot_y" "$output_contents" "$overrides_contents" )"
        mkdir -p "$cursors_output/$cursor_name" 2>/dev/null
        echo -n "$meta_hl_contents" > "$cursors_output/$cursor_name/meta.hl"
        (GLOBIGNORE="*_24*"; cp "$WORKING_SRC_DIR/volantes_cursors/$cursor_name"* "$cursors_output/$cursor_name")
    done

    set -e
    hyprcursor-util --create "$WORKING_DIR" --output "$WORKING_DIR/build" 1>/dev/null
    mv "$WORKING_DIR/build/theme_$OUTPUT_DISPLAY_NAME/"* "$WORKING_DIR/build"
    rmdir "$WORKING_DIR/build/theme_$OUTPUT_DISPLAY_NAME"
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

set -e

if [[ -d "$WORKING_DIR" ]]; then
    ([[ "$WORKING_DIR" != '/' ]] && rm -r "$WORKING_DIR"/*) || \
        (echo "error: no, I will not 'rm' recursively on root" 1>&2 || exit 4)
else
    mkdir "$WORKING_DIR" 
fi

mkdir "$WORKING_DIR/build"
cp -rd "$SRC_DIR" "$WORKING_DIR"

gen-hyprcursors
