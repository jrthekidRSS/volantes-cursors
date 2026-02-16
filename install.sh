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
readonly WORKING_CURSORS_DIR="$WORKING_DIR/cursors"
readonly OUTPUT_DISPLAY_NAME="Volantes Cursors"
readonly OUTPUT_DESCRIPTION="Design by varlesh"
readonly DEFAULT_CURSOR_SIZE=32

read -r -d '' HYPRCURSORS_MANIFEST_CONTENTS <<- EOF
name = $OUTPUT_DISPLAY_NAME
description = $OUTPUT_DESCRIPTION
cursors_directory = hyprcursors
EOF

read -r -d '' XCURSOR_INDEX_CONTENTS <<- EOF
[Icon Theme]
Name=$OUTPUT_DISPLAY_NAME
Comment=$OUTPUT_DESCRIPTION
EOF

cleanup() {
    rm -r "$WORKING_DIR" 2>/dev/null
}

print-help() {
cat <<- EOF
Usage: $SCRIPT_NAME [-ch]
EOF
}

build-cursors() {
    set -e
    readarray -t svg_files < <(ls -m1 "$WORKING_SRC_DIR/volantes_cursors")
    mkdir "$WORKING_CURSORS_DIR"
    # cursors_items format: CURSOR_NAME:FRAMES:OVERRIDES
    # FRAME format: HOTSPOT_X,HOTSPOT_Y,SIZE,FILENAME,[DELAY]
    # FRAMES format: FRAME;FRAME;FRAME;[...]
    local cursor_items=()

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

        local cursor_frames=() cursor_overrides=()

        # Read cursor's config file
        while IFS= read -r line; do
            local hotspot_x= hotspot_y=
            read -r size hotspot_x hotspot_y xcursor_filename delay <<< "$line"

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
            
            local cursor_frame_item="${hotspot_x},${hotspot_y},${size},${cursor_file}"

            if [[ -n "$delay" ]]; then
                cursor_frame_item="${cursor_frame_item},${delay}"
            fi

            cursor_frames+=("$cursor_frame_item")
        done < "$WORKING_SRC_DIR/config/$cursor_name.cursor"

        while read -r cursor_override _; do
            if [[ -n "$cursor_override" ]]; then
                cursor_overrides+=("$cursor_override")
            fi
        done < <(grep --color=never "${cursor_name}$" "$WORKING_SRC_DIR/cursorList" 2>/dev/null)

        mkdir -p "$WORKING_CURSORS_DIR/$cursor_name" 2>/dev/null
        cp "$WORKING_SRC_DIR/volantes_cursors/$cursor_name"* "$WORKING_CURSORS_DIR/$cursor_name"

        IFS=';'
        cursor_items+=("$cursor_name:${cursor_frames[*]}:${cursor_overrides[*]}")
        unset IFS
    done

    #(IFS=$'\n'; echo "${cursor_items[*]}")

    gen-hyprcursors "${cursor_items[@]}" &
    gen-svgcursors "${cursor_items[@]}" &
    wait
}

gen-hyprcursors() {
    set -eo pipefail
    echo -n "$HYPRCURSORS_MANIFEST_CONTENTS" > "$WORKING_DIR/manifest.hl"
    local cursors_output="$WORKING_DIR/hyprcursors"
    mkdir "$cursors_output"
    
    for cursor in "$@"; do
        local cursor_name= cursor_frames= cursor_overrides= meta_hl_contents=()

        IFS=':' read -r cursor_name cursor_frames cursor_overrides <<< "$cursor"

        mkdir "$cursors_output/$cursor_name"

        readarray -t -d ';' cursor_frames <<< "$cursor_frames"
        readarray -t -d ';' cursor_overrides <<< "$cursor_overrides"

        for cursor_frame in "${cursor_frames[@]}"; do
            while IFS=',' read -r hotspot_x hotspot_y size filename delay; do
                [[ -n "$filename" ]] || continue

                if [[ -z "${meta_hl_contents[*]}" ]]; then
                    meta_hl_contents+=("$(printf "hotspot_x = 0%s\nhotspot_y = 0%s" "$(bc <<< "scale=16; $hotspot_x / $size")" \
                        "$(bc <<< "scale=16; $hotspot_y / $size")")" '')
                fi

                local meta_hl_frame="define_size = ${size}, ${filename}"
                [[ -n "$delay" ]] && meta_hl_frame="${meta_hl_frame}, ${delay}"

                ln -s "$WORKING_CURSORS_DIR/$cursor_name/$filename" "$cursors_output/$cursor_name/$filename"
                meta_hl_contents+=("$meta_hl_frame")
            done <<< "$cursor_frame"
        done

        meta_hl_contents+=('')

        for cursor_override in "${cursor_overrides[@]}"; do
            # WHY DOES A LINE BREAK MAGICALLY APPEAR?????
            [[ -n "${cursor_override::-1}" ]] || continue

            meta_hl_contents+=("define_override = $cursor_override")
        done

        (IFS=$'\n'; printf '%s' "${meta_hl_contents[*]}" > "$cursors_output/$cursor_name/meta.hl")
    done

    #sleep 1000

    #return 0
    hyprcursor-util --create "$WORKING_DIR" --output "$WORKING_DIR/build" 1>/dev/null
    mv "$WORKING_DIR/build/theme_$OUTPUT_DISPLAY_NAME/"* "$WORKING_DIR/build"
    rmdir "$WORKING_DIR/build/theme_$OUTPUT_DISPLAY_NAME"
    exit 0
}

gen-svgcursors() {
    printf '%s' "$XCURSOR_INDEX_CONTENTS" > "$WORKING_DIR/index.theme"
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

build-cursors

sleep 1000
