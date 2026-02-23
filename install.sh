#!/usr/bin/env bash

readonly USER_ID="$(id -u)"

if [[ "$USER_ID" == 0 ]]; then
    OUTPUT_DIR="/usr/share/icons"
else
    OUTPUT_DIR="$HOME/.local/share/icons"
fi

readonly OUTPUT_NAME="volantes_cursors"
readonly SCRIPT_NAME="$(basename "$0")" readonly SCRIPT_DIR="$(dirname "$0")"
readonly SRC_DIR="$(dirname -- "$0")/src"
readonly WORKING_DIR="/tmp/$USER_ID-$OUTPUT_NAME"
readonly WORKING_CURSORS_DIR="$WORKING_DIR/cursors"
readonly OUTPUT_DISPLAY_NAME="Volantes Cursors"
readonly OUTPUT_DESCRIPTION="Design by varlesh"
readonly DEFAULT_CURSOR_SIZE=32
readonly DOUBLE_TAB=$'\t\t'
readonly CURSOR_COLORS=(
    "232627:cursor_fg:"
    "efefef:cursor_bg:"
    "d728d7:mauve:alias"
    "ff8a15:peach:context-menu"
    "47a400:green:copy"
    "435ece:sapphire:dnd-ask"
    "7753c5:lavender:dnd-link"
    "ef326f:red:dnd-no-drop"
    "3d5cdb:blue:help"
    "ff1a1a:red:pirate"
    "ff8a15:peach:wayland-cursor"
    "00aea9:teal:progress"
    "00aea9:teal:wait"
    "ab6439:rosewater:x-cursor"
)

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

read -r -d '' JQ_FORMAT <<- "EOF"
"\(.color.cursor_fg)
\(.color.cursor_bg)
\(.color.teal)
\(.color.red)
\(.color.green)
\(.color.rosewater)
\(.color.sapphire)
\(.color.lavender)
\(.color.mauve)
\(.color.peach)
\(.color.blue)"
EOF

read -r -d '' THEME_JSON_FORMAT <<- EOF
{
    "cursor_fg": "%s",
    "cursor_bg": "%s",
    "teal": "%s",
    "red": "%s",
    "green": "%s",
    "rosewater": "%s",
    "sapphire": "%s",
    "lavender": "%s",
    "mauve": "%s",
    "peach": "%s",
    "blue": "%s"
}
EOF

cleanup() {
    rm -r "$WORKING_DIR" 2>/dev/null
}

print-help() {
cat <<- EOF
Usage: $SCRIPT_NAME [-ch]

Options:
    -h, --help              Show this help
    -c, --cached-theme      Location of injected .json file
    -d, --target-directory  Location of theme's target directory
EOF
}

inject-colors() {
    local jq_output
    set -e
    jq_output="$(jq -r "$JQ_FORMAT" "$CACHED_THEME_FILE" 2>/dev/null)"
    set +e

    IFS=$'\n' read -r -d '' cursor_fg cursor_bg teal red \
    green rosewater sapphire lavender mauve peach blue  \
    <<< "$jq_output"

    local json_output="$(printf "$THEME_JSON_FORMAT" "${cursor_fg:-null}" "${cursor_bg:-null}" \
    "${teal:-null}" "${red:-null}" "${green:-null}" "${rosewater:-null}" "${sapphire:-null}" "${lavender:-null}" "${mauve:-null}" "${peach:-null}" "${blue:-null}")"

    if [[ "$json_output" == "$(cat "$OUTPUT_DIR/$OUTPUT_NAME/theme.json" 2>/dev/null)" ]]; then
        echo "warning: '$OUTPUT_NAME' is already installed" 1>&2
        exit 0
    fi

    shopt -u nullglob

    for line in "${CURSOR_COLORS[@]}"; do
        IFS=: read -r color_code color_name cursor_name <<< "$line"

        if [[ -z "${!color_name}" ]] || [[ "${!color_name}" == null ]]; then
            continue
        fi

        sed -i "s/#$color_code/#%$color_name%/g" "$WORKING_CURSORS_DIR"/"$cursor_name"*
    done

    for line in "${CURSOR_COLORS[@]}"; do
        IFS=: read -r color_code color_name cursor_name <<< "$line"

        if [[ -z "${!color_name}" ]] || [[ "${!color_name}" == null ]]; then
            continue
        fi

        sed -i "s/%${color_name}%/${!color_name}/g" "$WORKING_CURSORS_DIR"/"$cursor_name"*
    done

    echo "$json_output" > "$WORKING_DIR/build/theme.json"
}

install-cursors() {
    set -e

    cp -rdT "$WORKING_DIR/build" "$OUTPUT_DIR/$OUTPUT_NAME"
}

build-cursors() {
    set -e
    readarray -t svg_files < <(ls -m1 "$WORKING_CURSORS_DIR")
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

            if [[ "$size" != 32 ]]; then
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
        done < "$SRC_DIR/config/$cursor_name.cursor"

        while read -r cursor_override _; do
            if [[ -n "$cursor_override" ]]; then
                cursor_overrides+=("$cursor_override")
            fi
        done < <(grep --color=never "${cursor_name}$" "$SRC_DIR/cursorList" 2>/dev/null)

        IFS=';'
        cursor_items+=("$cursor_name:${cursor_frames[*]}:${cursor_overrides[*]}")
        unset IFS
    done

    gen-hyprcursors "${cursor_items[@]}" &
    gen-xcursors "${cursor_items[@]}" &
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
                # The cursor will be animated otherwise
                [[ "$size" != 24 ]] || continue

                if [[ -z "${meta_hl_contents[*]}" ]]; then
                    meta_hl_contents+=("$(printf "hotspot_x = 0%s\nhotspot_y = 0%s" "$(bc <<< "scale=16; $hotspot_x / $size")" \
                        "$(bc <<< "scale=16; $hotspot_y / $size")")" '')
                fi

                local meta_hl_frame="define_size = ${size}, ${filename}"
                [[ -n "$delay" ]] && meta_hl_frame="${meta_hl_frame}, ${delay}"

                ln -s "$WORKING_CURSORS_DIR/$filename" "$cursors_output/$cursor_name/$filename"
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

    hyprcursor-util --create "$WORKING_DIR" --output "$WORKING_DIR/build" 1>/dev/null
    mv "$WORKING_DIR/build/theme_$OUTPUT_DISPLAY_NAME/"* "$WORKING_DIR/build"
    rmdir "$WORKING_DIR/build/theme_$OUTPUT_DISPLAY_NAME"
}

gen-xcursors() {
    set -eo pipefail
    echo -n "$XCURSOR_INDEX_CONTENTS" > "$WORKING_DIR/build/index.theme"
    local svgcursors_output="$WORKING_DIR/build/cursors_scalable"
    local xcursors_output="$WORKING_DIR/build/cursors"
    local overrides=()
    mkdir "$svgcursors_output" "$xcursors_output"
    
    for cursor in "$@"; do
        local cursor_name= cursor_frames= cursor_overrides= metadata_json_contents=('[')

        IFS=':' read -r cursor_name cursor_frames cursor_overrides <<< "$cursor"

        mkdir "$svgcursors_output/$cursor_name"

        readarray -t -d ';' cursor_frames <<< "$cursor_frames"
        readarray -t -d ';' cursor_overrides <<< "$cursor_overrides"

        for cursor_frame_index in "${!cursor_frames[@]}"; do
            while IFS=',' read -r hotspot_x hotspot_y size filename delay; do
                [[ -n "$filename" ]] || continue
                [[ -n "$delay" ]] && size="${size},"

                metadata_json_contents+=(
                    $'\t{'
                    "${DOUBLE_TAB}\"filename\": \"$filename\","
                    "${DOUBLE_TAB}\"hotspot_x\": $hotspot_x,"
                    "${DOUBLE_TAB}\"hotspot_y\": $hotspot_y,"
                    "${DOUBLE_TAB}\"nominal_size\": $size"
                )
                
                [[ -n "$delay" ]] && metadata_json_contents+=("${DOUBLE_TAB}\"delay\": $delay")

                if [[ -n "${cursor_frames[cursor_frame_index + 1]}" ]]; then
                    metadata_json_contents+=($'\t},')
                else
                    metadata_json_contents+=($'\t}')
                fi

                cp "$WORKING_CURSORS_DIR/$filename" "$svgcursors_output/$cursor_name/$filename"
            done <<< "${cursor_frames[cursor_frame_index]}"
        done

        metadata_json_contents+=(']')

        for cursor_override in "${cursor_overrides[@]}"; do
            # WHY DOES A LINE BREAK MAGICALLY APPEAR?????
            [[ -n "${cursor_override::-1}" ]] || continue

            overrides+=("${cursor_name}:${cursor_override}")
        done

        (IFS=$'\n'; printf '%s' "${metadata_json_contents[*]}" > "$svgcursors_output/$cursor_name/metadata.json")
    done

    kcursorgen --svg-theme-to-xcursor --svg-dir "$svgcursors_output" \
    --xcursor-dir "$xcursors_output" --sizes '24,32' --scales '1,2,3' 2>/dev/null

    for override in "${overrides[@]}"; do
        IFS=':' read -r target link_name <<< "$override"

        if [[ ! -f "$xcursors_output/$link_name" ]]; then
            ln -s "$target" "$xcursors_output/$link_name"
        fi
    done

    cp "$SRC_DIR/volantes_cursors/cursor.theme" "$WORKING_DIR/build"
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
            c)
                CACHED_THEME_FILE="$value"
                ;;
            d)
                OUTPUT_DIR="$value"
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
        --cached-theme)
            parse-flags '-c' "$2"
            shift
            ;;
        --target-directory)
            parse-flags '-d' "$2"
            shift
            ;;
        --*)
            printf "error: invalid parameter '%s'\n%s\n" "$1" "$(print-help)" 1>&2
            exit 2
            ;;
        -*)
            parse-flags "$1" "$2"

            case "$1" in
                *c*|*d*)
                    shift
                    ;;
            esac
            ;;
        *)
            printf "error: invalid parameter '%s'\n%s\n" "$1" "$(print-help)" 1>&2
            exit 2
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

mkdir "$WORKING_DIR/build" "$WORKING_CURSORS_DIR"
shopt -s extglob nullglob
cp -d -t "$WORKING_CURSORS_DIR" "$SRC_DIR/volantes_cursors"/!(*_24.svg|*.theme)
shopt -u extglob nullglob

inject-colors || :
build-cursors
install-cursors
