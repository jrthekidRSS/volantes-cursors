#!/usr/bin/env bash

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(dirname "$0")"

print-help() {
cat <<- EOF
Usage: $SCRIPT_NAME [-ch]
EOF
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

