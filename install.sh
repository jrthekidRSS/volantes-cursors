#!/usr/bin/env sh

. "$SHSTD/mod.sh"
lib_source std/types/path std/parse-args

readonly UID="$(id -u)"

if [ "$UID" = 0 ]; then
	OUTPUT_DIR="/usr/share/icons"
else
	OUTPUT_DIR="${XDG_DATA_HOME:-"$HOME/.local/share"}/icons"
fi

readonly OUTPUT_NAME="volantes_cursors"
readonly SCRIPT_DIR="$(dirname "$0")"
readonly SRC_DIR="$SCRIPT_DIR/src"
readonly OUTPUT_DISPLAY_NAME="Volantes Cursors"
readonly OUTPUT_DESCRIPTION="Design by varlesh"
readonly DEFAULT_CURSOR_SIZE=32
readonly DOUBLE_TAB=$'\t\t'
CURSOR_COLORS='
232627:cursor_fg:
efefef:cursor_bg:
d728d7:mauve:alias
ff8a15:peach:context-menu
47a400:green:copy
435ece:sapphire:dnd-ask
7753c5:lavender:dnd-link
ef326f:red:dnd-no-drop
3d5cdb:blue:help
ff1a1a:red:pirate
ff8a15:peach:wayland-cursor
00aea9:teal:progress
00aea9:teal:wait
ab6439:rosewater:x-cursor
'

readonly HYPRCURSORS_MANIFEST_CONTENTS="\
name = $OUTPUT_DISPLAY_NAME
description = $OUTPUT_DESCRIPTION
cursors_directory = hyprcursors"

XCURSOR_INDEX_CONTENTS="\
[Icon Theme]
Name=$OUTPUT_DISPLAY_NAME
Comment=$OUTPUT_DESCRIPTION"

cleanup() {
	rm -r "$WORKING_DIR" 2>/dev/null
}

print_help() {
cat <<- EOF
Usage: $SCRIPT_NAME [-ch]

Options:
	-h, --help			    Show this help
	-c, --cached-theme	    Location of injected .json file
	-d, --target-directory  Location of theme's target directory
	-s, --cursor-size       Intended size of cursor
	                        Sizes less or equal to 24 will use a slightly
							different theme
	-f, --force             Install even if already installed
EOF
}

inject_theme() {
	mkdir "$WORKING_DIR/shell_formats"
	SHELL_FORMAT="#${WORKING_DIR}$LF${SHELL_FORMAT}"
	THEME_JSON_FORMAT="#${WORKING_BUILD_DIR}$LF${THEME_JSON_FORMAT}"
	echo "$SHELL_FORMAT" > "$WORKING_DIR/shell_formats/theme.sh"
	echo "$THEME_JSON_FORMAT" > "$WORKING_DIR/shell_formats/theme.json"
	echo "$FALLBACK_JSON_THEME" > "$WORKING_DIR/fallback_colors.json"
	theme-injector -Ef "$WORKING_DIR/shell_formats" "$WORKING_DIR/fallback_colors.json" "$CACHED_THEME_FILE" || return 0
	. "$WORKING_DIR/theme.sh"


	if [ "$(cat "$WORKING_BUILD_DIR/theme.json")" = "$(cat "$OUTPUT_DIR/$OUTPUT_NAME/theme.json" 2>/dev/null || :)" ] && \
		! $FORCE_INSTALL; then
		echoerr "warning: '$OUTPUT_NAME' is already installed"
		exit 0
	fi

	mkdir "$WORKING_DIR/cursor_formats"
	cp -rt "$WORKING_DIR/cursor_formats" "$WORKING_CURSORS_DIR"/*.svg
	IFS_stsh "$LF"

	for __inject_theme_line in $CURSOR_COLORS; do
		IFS=":$LF"

		read -r __inject_theme_hex __inject_theme_name __inject_theme_cursor <<- EOF
		$__inject_theme_line
		EOF

		eval "
		if [ \"_theme_$__inject_theme_name\" = \"\$__inject_theme_hex\" \\
			-o \"_theme_$__inject_theme_name\" = null ]; then continue; fi
		"

		sed -i -s -e "s+#$__inject_theme_hex+#%$__inject_theme_name%+g" "$WORKING_DIR/cursor_formats/$__inject_theme_cursor"*.svg
	done

	IFS_rstr
	sed -i -s -z -e "s+^+#${WORKING_CURSORS_DIR}\n+" "$WORKING_DIR/cursor_formats/"*
	theme-injector -Ef "$WORKING_DIR/cursor_formats" "$WORKING_BUILD_DIR/theme.json"
}

install_cursors() {
	cp -rdT "$WORKING_BUILD_DIR" "$OUTPUT_DIR/$OUTPUT_NAME"
}

build_cursors() {
	# cursors_items format: CURSOR_NAME:FRAMES:OVERRIDES
	# FRAME format: HOTSPOT_X,HOTSPOT_Y,SIZE,FILENAME,[DELAY]
	# FRAMES format: FRAME;FRAME;FRAME;[...]
	# OVERRIDES format: [OVERRIDE;OVERRIDE;...]
	__build_cursors_cursor_items=
	__build_cursors_cursorList="$LF$(cat "$SRC_DIR/cursorList" 2>/dev/null)$LF"

	cd "$WORKING_CURSORS_DIR"
	for __build_cursors_svg in *; do
		case "$__build_cursors_svg" in
			*_24.svg)
				continue
				;;
			*-00.svg | *-0[2-9].svg | *-[1-9][[:digit:]].svg)
				continue
				;;
			*-01.svg)
				__build_cursors_cursor_name="${__build_cursors_svg%-01.svg}"
				;;
			*.svg)
				__build_cursors_cursor_name="${__build_cursors_svg%.svg}"
				;;
			*)
				continue
				;;
		esac

		__build_cursors_cursor_frames=
		__build_cursors_cursor_overrides=

		# Read cursor's config file
		while read -r __build_cursors_line; do
			__build_cursors_hotspot_x=
			__build_cursors_hotspot_y=
			read -r __build_cursors_cursor_size \
				__build_cursors_hotspot_x \
				__build_cursors_hotspot_y \
				__build_cursors_cursor_filename \
				__build_cursors_cursor_delay \
			<<- EOF
			$__build_cursors_line
			EOF

			if [ "$CURSOR_SIZE" -le 24 -a "$__build_cursors_cursor_size" = 24 ] || \
				[ "$CURSOR_SIZE" -gt 24 -a "$__build_cursors_cursor_size" = 32 ]; then
				:
			else
				continue
			fi

			# Animated cursors are made up of files with slightly different
			# names between each other
			__build_cursors_cursor_file="$__build_cursors_svg"
			__build_cursors_cursor_frame="${__build_cursors_cursor_filename%_[[:digit:]][[:digit:]].png}"

			[ "$__build_cursors_cursor_frame" = "$__build_cursors_cursor_name" ] || \
				__build_cursors_cursor_file="${__build_cursors_cursor_frame}.svg"
			
			__build_cursors_cursor_frame_item="${__build_cursors_hotspot_x},${__build_cursors_hotspot_y},${__build_cursors_cursor_size},${__build_cursors_cursor_file}${__build_cursors_cursor_delay:+",${__build_cursors_cursor_delay}"}"

			__build_cursors_cursor_frames="$__build_cursors_cursor_frames${__build_cursors_cursor_frames:+;}$__build_cursors_cursor_frame_item"
		done < "$SRC_DIR/config/$__build_cursors_cursor_name.cursor"

		case "$__build_cursors_cursorList" in
			*" ${__build_cursors_cursor_name}$LF"*)
				IFS_stsh "$LF"

				for __build_cursors_working_override in $__build_cursors_cursorList; do
					case "$__build_cursors_working_override" in
						*" $__build_cursors_cursor_name")
							__build_cursors_working_override="${__build_cursors_working_override%%[[:space:]]*}"
							__build_cursors_cursor_overrides="$__build_cursors_cursor_overrides${__build_cursors_cursor_overrides:+";"}$__build_cursors_working_override"
							;;
					esac
				done

				IFS_rstr
				;;
		esac

		__build_cursors_cursor_items="$__build_cursors_cursor_items${__build_cursors_cursor_items:+"$LF"}$__build_cursors_cursor_name:$__build_cursors_cursor_frames"
		__build_cursors_cursor_items="$__build_cursors_cursor_items${__build_cursors_cursor_overrides:+:}$__build_cursors_cursor_overrides"
	done

	IFS_stsh "$LF"
	__build_cursors_gen_hyprcursors $__build_cursors_cursor_items &
	__build_cursors_gen_xcursors $__build_cursors_cursor_items &
	wait
	IFS_rstr
}

__build_cursors_gen_hyprcursors() {
	printf %s "$HYPRCURSORS_MANIFEST_CONTENTS" > "$WORKING_DIR/manifest.hl"
	__build_cursors_gen_hyprcursors_cursors_output="$WORKING_DIR/hyprcursors"
	mkdir "$__build_cursors_gen_hyprcursors_cursors_output"
	
	for __build_cursors_gen_hyprcursors_cursor in "$@"; do
		__build_cursors_gen_hyprcursors_meta_hl_contents=

		IFS_stsh :
		read -r \
		__build_cursors_gen_hyprcursors_cursor_name \
		__build_cursors_gen_hyprcursors_cursor_frames \
		__build_cursors_gen_hyprcursors_cursor_overrides \
		<<- EOF
		$__build_cursors_gen_hyprcursors_cursor
		EOF

		IFS=';'
		: "$__build_cursors_gen_hyprcursors_cursor"
		: $__build_cursors_gen_hyprcursors_cursor_frames
		mkdir "$__build_cursors_gen_hyprcursors_cursors_output/$__build_cursors_gen_hyprcursors_cursor_name"

		for __build_cursors_gen_hyprcursors_cursor_frame in $__build_cursors_gen_hyprcursors_cursor_frames; do
			: $__build_cursors_gen_hyprcursors_cursor_frame
			while IFS=',' read -r \
				__build_cursors_gen_hyprcursors_hotspot_x \
				__build_cursors_gen_hyprcursors_hotspot_y \
				__build_cursors_gen_hyprcursors_size \
				__build_cursors_gen_hyprcursors_filename \
				__build_cursors_gen_hyprcursors_delay \
				|| [ -n "$__build_cursors_gen_hyprcursors_filename" ]; do

				[ -n "$__build_cursors_gen_hyprcursors_filename" ] || continue

				if [ -z "$__build_cursors_gen_hyprcursors_meta_hl_contents" ]; then
					__build_cursors_gen_hyprcursors_working_float="$(( __build_cursors_gen_hyprcursors_hotspot_x + 1 ))"
					__build_cursors_gen_hyprcursors_working_float="${__build_cursors_gen_hyprcursors_working_float}00"
					__build_cursors_gen_hyprcursors_working_float="$(( __build_cursors_gen_hyprcursors_working_float / __build_cursors_gen_hyprcursors_size ))"
					[ "${#__build_cursors_gen_hyprcursors_working_float}" -gt 1 ] || __build_cursors_gen_hyprcursors_working_float="0$__build_cursors_gen_hyprcursors_working_float"
					[ "${#__build_cursors_gen_hyprcursors_working_float}" -gt 2 ] || __build_cursors_gen_hyprcursors_working_float="0$__build_cursors_gen_hyprcursors_working_float"
					__build_cursors_gen_hyprcursors_working_int="${__build_cursors_gen_hyprcursors_working_float%[[:digit:]][[:digit:]]}"
					__build_cursors_gen_hyprcursors_working_float="${__build_cursors_gen_hyprcursors_working_float#"$__build_cursors_gen_hyprcursors_working_int"}"
					__build_cursors_gen_hyprcursors_hotspot_x="${__build_cursors_gen_hyprcursors_working_int:-0}.$__build_cursors_gen_hyprcursors_working_float"
					__build_cursors_gen_hyprcursors_working_float="$(( __build_cursors_gen_hyprcursors_hotspot_y + 1 ))"
					__build_cursors_gen_hyprcursors_working_float="${__build_cursors_gen_hyprcursors_working_float}00"
					__build_cursors_gen_hyprcursors_working_float="$(( __build_cursors_gen_hyprcursors_working_float / __build_cursors_gen_hyprcursors_size ))"
					[ "${#__build_cursors_gen_hyprcursors_working_float}" -gt 1 ] || __build_cursors_gen_hyprcursors_working_float="0$__build_cursors_gen_hyprcursors_working_float"
					[ "${#__build_cursors_gen_hyprcursors_working_float}" -gt 2 ] || __build_cursors_gen_hyprcursors_working_float="0$__build_cursors_gen_hyprcursors_working_float"
					__build_cursors_gen_hyprcursors_working_int="${__build_cursors_gen_hyprcursors_working_float%[[:digit:]][[:digit:]]}"
					__build_cursors_gen_hyprcursors_working_float="${__build_cursors_gen_hyprcursors_working_float#"$__build_cursors_gen_hyprcursors_working_int"}"
					__build_cursors_gen_hyprcursors_hotspot_y="${__build_cursors_gen_hyprcursors_working_int:-0}.$__build_cursors_gen_hyprcursors_working_float"
					__build_cursors_gen_hyprcursors_meta_hl_contents="$__build_cursors_gen_hyprcursors_meta_hl_contents${__build_cursors_gen_hyprcursors_meta_hl_contents:+"$LF"}hotspot_x = $__build_cursors_gen_hyprcursors_hotspot_x${LF}hotspot_y = $__build_cursors_gen_hyprcursors_hotspot_y"
				fi

				__build_cursors_gen_hyprcursors_meta_hl_frame="define_size = $__build_cursors_gen_hyprcursors_size, ${__build_cursors_gen_hyprcursors_filename}"
				[ -z "$__build_cursors_gen_hyprcursors_delay" ] || __build_cursors_gen_hyprcursors_meta_hl_frame="${__build_cursors_gen_hyprcursors_meta_hl_frame}, ${__build_cursors_gen_hyprcursors_delay}"
				link "$WORKING_CURSORS_DIR/$__build_cursors_gen_hyprcursors_filename" "$__build_cursors_gen_hyprcursors_cursors_output/$__build_cursors_gen_hyprcursors_cursor_name/$__build_cursors_gen_hyprcursors_filename"

				__build_cursors_gen_hyprcursors_meta_hl_contents="$__build_cursors_gen_hyprcursors_meta_hl_contents${__build_cursors_gen_hyprcursors_meta_hl_contents:+"$LF"}$__build_cursors_gen_hyprcursors_meta_hl_frame"
			done <<- EOF
			$__build_cursors_gen_hyprcursors_cursor_frame
			EOF
		done

		__build_cursors_gen_hyprcursors_meta_hl_contents="$__build_cursors_gen_hyprcursors_meta_hl_contents$LF"

		for __build_cursors_gen_hyprcursors_cursor_override in $__build_cursors_gen_hyprcursors_cursor_overrides; do
			__build_cursors_gen_hyprcursors_meta_hl_contents="$__build_cursors_gen_hyprcursors_meta_hl_contents${LF}define_override = $__build_cursors_gen_hyprcursors_cursor_override"
		done

		echor "$__build_cursors_gen_hyprcursors_meta_hl_contents" >> "$__build_cursors_gen_hyprcursors_cursors_output/$__build_cursors_gen_hyprcursors_cursor_name/meta.hl"
		IFS_rstr
	done

	hyprcursor-util --create "$WORKING_DIR" --output "$WORKING_BUILD_DIR" 1>/dev/null
	mv -t "$WORKING_BUILD_DIR" "$WORKING_BUILD_DIR/theme_$OUTPUT_DISPLAY_NAME/"*
	rmdir "$WORKING_BUILD_DIR/theme_$OUTPUT_DISPLAY_NAME"
}

__build_cursors_gen_xcursors() {
	printf %s "$XCURSOR_INDEX_CONTENTS" > "$WORKING_BUILD_DIR/index.theme"
	__build_cursors_gen_xcursors_svgcursors_output="$WORKING_BUILD_DIR/cursors_scalable"
	__build_cursors_gen_xcursors_xcursors_output="$WORKING_BUILD_DIR/cursors"
	#__build_cursors_gen_xcursors_overrides=
	mkdir "$__build_cursors_gen_xcursors_svgcursors_output" "$__build_cursors_gen_xcursors_xcursors_output"
	IFS_stsh ';'
	
	for __build_cursors_gen_xcursors_cursor in "$@"; do
		__build_cursors_gen_xcursors_cursor_name=
		__build_cursors_gen_xcursors_cursor_frames=
		__build_cursors_gen_xcursors_cursor_overrides=
		__build_cursors_gen_xcursors_metadata_json_contents=

		IFS=':' read -r __build_cursors_gen_xcursors_cursor_name \
		__build_cursors_gen_xcursors_cursor_frames \
		__build_cursors_gen_xcursors_cursor_overrides \
		<<- EOF
		$__build_cursors_gen_xcursors_cursor
		EOF

		[ ! -L "$__build_cursors_gen_xcursors_xcursor_output/$__build_cursors_gen_xcursors_cursor_name" ] || \
			unlink "$__build_cursors_gen_xcursors_xcursor_output/$__build_cursors_gen_xcursors_cursor_name"
		mkdir "$__build_cursors_gen_xcursors_svgcursors_output/$__build_cursors_gen_xcursors_cursor_name"

		for __build_cursors_gen_xcursors_cursor_frame in $__build_cursors_gen_xcursors_cursor_frames; do
			while IFS=',' read -r \
				__build_cursors_gen_xcursors_hotspot_x \
				__build_cursors_gen_xcursors_hotspot_y \
				__build_cursors_gen_xcursors_size \
				__build_cursors_gen_xcursors_filename \
				__build_cursors_gen_xcursors_delay; do
				[ -n "$__build_cursors_gen_xcursors_filename" ] || continue

				echo
				__build_cursors_gen_xcursors_working_int="$(( __build_cursors_gen_xcursors_hotspot_x + 1 ))"
				echo "1 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				__build_cursors_gen_xcursors_working_int="${__build_cursors_gen_xcursors_working_int}00"
				echo "2 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				__build_cursors_gen_xcursors_working_int="$(( __build_cursors_gen_xcursors_working_int / __build_cursors_gen_xcursors_size ))"
				echo "3 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				echo "size=$__build_cursors_gen_xcursors_size CURSOR_SIZE=$CURSOR_SIZE"
				__build_cursors_gen_xcursors_working_int="$(( __build_cursors_gen_xcursors_working_int * CURSOR_SIZE ))"
				echo "4 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				[ "${#__build_cursors_gen_xcursors_working_int}" -gt 1 ] || __build_cursors_gen_xcursors_working_int="0$__build_cursors_gen_xcursors_working_int"
				echo "5 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				[ "${#__build_cursors_gen_xcursors_working_int}" -gt 2 ] || __build_cursors_gen_xcursors_working_int="0$__build_cursors_gen_xcursors_working_int"
				echo "6 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				__build_cursors_gen_xcursors_working_int="${__build_cursors_gen_xcursors_working_int%[[:digit:]][[:digit:]]}"
				[ "$__build_cursors_gen_xcursors_working_int" -gt 1 ] || __build_cursors_gen_xcursors_working_int="$(( __build_cursors_gen_xcursors_working_int - 1 ))"
				echo "7 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				__build_cursors_gen_xcursors_hotspot_x="$__build_cursors_gen_xcursors_working_int"

				__build_cursors_gen_xcursors_working_int="$(( __build_cursors_gen_xcursors_hotspot_y + 1 ))"
				echo "8 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				__build_cursors_gen_xcursors_working_int="${__build_cursors_gen_xcursors_working_int}00"
				echo "9 $__build_cursors_gen_xcursors_hotspot_x: $__build_cursors_gen_xcursors_working_int"
				__build_cursors_gen_xcursors_working_int="$(( __build_cursors_gen_xcursors_working_int / __build_cursors_gen_xcursors_size ))"
				__build_cursors_gen_xcursors_working_int="$(( __build_cursors_gen_xcursors_working_int * CURSOR_SIZE ))"
				[ "${#__build_cursors_gen_xcursors_working_int}" -gt 1 ] || __build_cursors_gen_xcursors_working_int="0$__build_cursors_gen_xcursors_working_int"
				[ "${#__build_cursors_gen_xcursors_working_int}" -gt 2 ] || __build_cursors_gen_xcursors_working_int="0$__build_cursors_gen_xcursors_working_int"
				__build_cursors_gen_xcursors_working_int="${__build_cursors_gen_xcursors_working_int%[[:digit:]][[:digit:]]}"
				__build_cursors_gen_xcursors_hotspot_y="$(( __build_cursors_gen_xcursors_working_int - 1 ))"

				__build_cursors_gen_xcursors_metadata_json_contents="$__build_cursors_gen_xcursors_metadata_json_contents${__build_cursors_gen_xcursors_metadata_json_contents:+,}
	{
		\"filename\": \"$__build_cursors_gen_xcursors_filename\",
		\"hotspot_x\": $__build_cursors_gen_xcursors_hotspot_x,
		\"hotspot_y\": $__build_cursors_gen_xcursors_hotspot_y,
		\"nominal_size\": $__build_cursors_gen_xcursors_size"
				
				[ -z "$__build_cursors_gen_xcursors_delay" ] || __build_cursors_gen_xcursors_metadata_json_contents="$__build_cursors_gen_xcursors_metadata_json_contents,${LF}${HT}${HT}\"delay\": $__build_cursors_gen_xcursors_delay"

				__build_cursors_gen_xcursors_metadata_json_contents="${__build_cursors_gen_xcursors_metadata_json_contents}${LF}${HT}}"

				cp -T "$WORKING_CURSORS_DIR/$__build_cursors_gen_xcursors_filename" "$__build_cursors_gen_xcursors_svgcursors_output/$__build_cursors_gen_xcursors_cursor_name/$__build_cursors_gen_xcursors_filename"
			done <<- EOF
			$__build_cursors_gen_xcursors_cursor_frame
			EOF
		done

		__build_cursors_gen_xcursors_metadata_json_contents="[$LF${__build_cursors_gen_xcursors_metadata_json_contents}$LF]"

		for __build_cursors_gen_xcursors_cursor_override in $__build_cursors_gen_xcursors_cursor_overrides; do
			[ -f "$WORKING_CURSORS_DIR/$__build_cursors_gen_xcursors_cursor_override.svg" -o -f "$WORKING_CURSORS_DIR/$__build_cursors_gen_xcursors_cursor_override-01.svg" ] || \
				ln -s "$__build_cursors_gen_xcursors_cursor_name" "$__build_cursors_gen_xcursors_xcursors_output/$__build_cursors_gen_xcursors_cursor_override"
		done

		printf %s "$__build_cursors_gen_xcursors_metadata_json_contents" > "$__build_cursors_gen_xcursors_svgcursors_output/$__build_cursors_gen_xcursors_cursor_name/metadata.json"
	done

	kcursorgen --svg-theme-to-xcursor --svg-dir "$__build_cursors_gen_xcursors_svgcursors_output" \
		--xcursor-dir "$__build_cursors_gen_xcursors_xcursors_output" --sizes "$CURSOR_SIZE" --scales '1' 2>/dev/null
	IFS="$LF"

	IFS_rstr
	cp -T "$SRC_DIR/volantes_cursors/cursor.theme" "$WORKING_BUILD_DIR/cursor.theme"
}

parse_args "$@" << FMT
c:cached-theme:CACHED_THEME_FILE:string:$CACHED_THEME_FILE
d:target-directory:OUTPUT_DIR:string:$OUTPUT_DIR
s:cursor-size:CURSOR_SIZE:string:$DEFAULT_CURSOR_SIZE
f:force:FORCE_INSTALL:bool:false
FMT

case $? in
    1)
        print_help
        exit 0
        ;;
    2)
        print_help 1>&2
        exit 1
        ;;
    [!0]*)
        exit 4
        ;;
esac

if ! [ "$CURSOR_SIZE" -gt 0 ] 2>/dev/null; then
	echoerr "error: cursor size is not a valid positive integer"
	exit 4
fi

SHELL_FORMAT=
THEME_JSON_FORMAT=
FALLBACK_JSON_FORMAT=
IFS_stsh "$LF"

for __color in $CURSOR_COLORS; do
	IFS=":${IFS}"
	[ -n "$__color" ] || continue

	read -r __hex __name _ <<- EOF
	$__color
	EOF

	SHELL_FORMAT="${SHELL_FORMAT}${SHELL_FORMAT:+"$LF"}_theme_$__name='$__hex'"
	THEME_JSON_FORMAT="${THEME_JSON_FORMAT}${THEME_JSON_FORMAT:+"$LF"}${HT}\"$__name\": \"%color.$__name%\","
	FALLBACK_JSON_FORMAT="${FALLBACK_JSON_FORMAT}${FALLBACK_JSON_FORMAT:+"$LF"}${HT}\"$__name\": \"$__hex\","
done

SHELL_FORMAT="$SHELL_FORMAT
_theme_size=$CURSOR_SIZE"
THEME_JSON_FORMAT="{
$THEME_JSON_FORMAT
	\"size\": $CURSOR_SIZE
}"

FALLBACK_JSON_THEME="{
$FALLBACK_JSON_FORMAT
	\"size\": 32
}"

IFS_rstr

set -e

WORKING_DIR="$(mktemp -d)"
WORKING_BUILD_DIR="$WORKING_DIR/build"
WORKING_CURSORS_DIR="$WORKING_DIR/cursors"
trap cleanup EXIT
trap 'err=$?; cleanup; exit $?' TERM INT QUIT

mkdir "$WORKING_BUILD_DIR" "$WORKING_CURSORS_DIR"
cp -dt "$WORKING_CURSORS_DIR" "$SRC_DIR/volantes_cursors"/*.svg

inject_theme || :
build_cursors
install_cursors
