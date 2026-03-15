#!/usr/bin/env bash
# SPDX-License-Identifier: 0BSD
# This is cyc: https://github.com/mrpg/cyc

set -euo pipefail

markopen="{{"
markclos="}}"

# Track temp files for cleanup
temp_files=()

cleanup () {
    # Clean up temporary files on exit
    for tmp in "${temp_files[@]}"; do
        [[ -f "$tmp" ]] && rm -f "$tmp"
    done
}

trap cleanup EXIT INT TERM

check_dependencies () {
    # Verify required tools are available
    local missing=()

    for cmd in grep sed cut rev find dirname mktemp; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ! -f "bin/replace" || ! -x "bin/replace" ]]; then
        echo "Error: bin/replace not found or not executable." >&2
        exit 6
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Missing required commands: ${missing[*]}" >&2
        exit 7
    fi
}

apply_exec () {
    # Replace execution marks with the output of the command in file
    # $1, where $2 is the root name of the file.

    tmpout=$(mktemp)
    temp_files+=("$tmpout")

    cp "$1" "$tmpout"

    execs=$({ grep -o "$markopen""\^\^[^\^]*\^\^$markclos" "$tmpout" || true; } |
        sort |
        uniq |
        sed 's/^'"$markopen"'\^\^//g' | sed 's/\^\^'"$markclos"'$//g')

    echo "$execs" |
        while IFS= read -r one_exec
        do
            [[ -z "$one_exec" ]] && continue
            cmdout=$(mktemp)
            temp_files+=("$cmdout")

            # Split into command and argument (if present)
            read -r cmd arg rest <<< "$one_exec"

            if [[ -n "$rest" ]]; then
                bail 2 "Error: '$one_exec' has too many arguments. Commands may have at most one argument in cyc templates."
            fi

            echo "CYC_EXEC: '$cmd' ($2)..." >&2
            (
                export CYC_FILE=$2
                if [[ -n "$arg" ]]; then
                    export CYC_ARG="$arg"
                fi

                exec "$cmd"
            ) > "$cmdout" || {
                bail 2 "Error: Could not run '$cmd'. Commands may have at most one argument in cyc templates. You should write a shell script that can be called in a standalone manner."
            }

            replace_in_place "$tmpout" "$markopen""^^""$one_exec""^^$markclos" "$cmdout"
            rm -f "$cmdout"
        done

    mv "$tmpout" "$1" || bail 14 "Error: Failed to write output to $1"
}

apply_includes () {
    # Replace inclusion marks ("includes") with the referenced file in
    # file $1, where $2 is a preferred search path for included files.
    # If $2/included does not exist, attempt to use template/included, etc.

    tmpout=$(mktemp)
    temp_files+=("$tmpout")

    cp "$1" "$tmpout"

    includes=$({ grep -o "$markopen""##[^#]*##$markclos" "$tmpout" || true; } |
        sort |
        uniq |
        sed 's/^'"$markopen"'##//g' | sed 's/##'"$markclos"'$//g')

    echo "$includes" |
        while IFS= read -r one_include
        do
            [[ -z "$one_include" ]] && continue

            origin="$2/$one_include"
            [[ -f "$origin" ]] || origin="meta/$one_include"
            [[ -f "$origin" ]] || origin="template/$one_include"
            [[ -f "$origin" ]] || origin="static/$one_include"
            [[ -f "$origin" ]] || origin="$one_include"

            [[ -f "$origin" ]] || {
                bail 2 "Error: Included file $one_include not found (last checked: $origin)."
            }

            replace_in_place "$tmpout" "$markopen""##""$one_include""##$markclos" "$origin"
        done

    mv "$tmpout" "$1" || bail 15 "Error: Failed to write output to $1"
}

apply_once () {
    # Merge (body) file content/$1 into template $2, with output written
    # to public/$1. This function loops until no fields or includes are
    # left in the resulting file.

    target="public/$1"
    target_dir=$(dirname "$target")

    [[ -d "$target_dir" ]] || mkdir -p "$target_dir" || {
        bail 12 "Error: Failed to create directory $target_dir"
    }

    cp "$2" "$target" || bail 13 "Error: Failed to copy template $2 to $target"

    while needs_templating "$target"
    do
        fields=$({ grep -o "$markopen""!![^!]*!!$markclos" "$target" || true; } |
            sort |
            uniq |
            sed 's/^'"$markopen"'!!//g' | sed 's/!!'"$markclos"'$//g')

        echo "$fields" |
            while IFS= read -r one_field
            do
                [[ -z "$one_field" ]] && continue
                [[ "$one_field" == "body" ]] && continue

                origin="meta/$1.$one_field"
                [[ -f "$origin" ]] || origin="content/$1.$one_field"

                [[ -f "$origin" ]] || {
                    bail 3 "Error: $origin was not found (also not in meta/)."
                }

                replace_in_place "$target" "$markopen""!!""$one_field""!!$markclos" "$origin"
            done

        replace_in_place "$target" "$markopen""!!body!!$markclos" "content/$1"

        apply_includes "$target" "$(dirname "content/$1")"
        apply_exec "$target" "$1"
    done
}

bail () {
    # Fail with exit code $1 and message $2

    echo "$2" 1>&2

    # Kill all background jobs
    jobs -p | xargs -r kill 2>/dev/null

    rm -rf public
    exit "$1"
}

extension () {
    # Ascertain the extensions of the filenames in stdin

    rev | cut -d'.' -f1 | rev
}

needs_templating () {
    # Returns a non-failing exit code if file $1 includes fields or
    # includes.

    {
        grep "$markopen""!![^!]*!!$markclos" "$1" || \
            grep "$markopen""##[^#]*##$markclos" "$1" || \
            grep "$markopen""\^\^[^\^]*\^\^$markclos" "$1"
    } > /dev/null 2>&1
}

replace_in_place () {
    # In-place replace the string $2 with the contents of file $3,
    # in file $1. Note that bin/replace works with stdin/stdout.

    tmpf=$(mktemp)
    temp_files+=("$tmpf")

    bin/replace "$2" "$3" < "$1" > "$tmpf" || {
        echo "Error: bin/replace failed while processing $1" >&2
        exit 16
    }
    mv "$tmpf" "$1" || {
        echo "Error: Failed to write output to $1" >&2
        exit 17
    }
}

resolve_template () {
    # Find the template that should be applied to $1. First, checks if
    # {meta/,content/}$1.template exists. If not, check for default
    # templates first in any corresponding subdirectory of template/, then
    # in the parent directories.

    cfile="content/$1"
    mfile="meta/$1"
    ext=$(echo "$1" | extension)

    [[ -f "$mfile.template" ]] && cat "$mfile.template" && return 0
    [[ -f "$cfile.template" ]] && cat "$cfile.template" && return 0

    while :
    do
        cfile=$(dirname "$cfile")
        candidate="${cfile#content}/default.$ext"
        [[ -f "template/$candidate" ]] && echo "$candidate" && return 0

        [[ "$cfile" == "content" ]] && break
    done

    echo "default.$ext" && return 1
}

unext () {
    # Remove extensions from the filenames in stdin

    rev | cut -d'.' -f2- | rev
}

check_dependencies

[[ -d content ]] || bail 4 "Error: content/ directory does not exist."
[[ -d template ]] || bail 5 "Error: template/ directory does not exist."

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <pattern> [pattern...]" >&2
    echo "Error: At least one file pattern is required." >&2
    exit 8
fi

rm -rf public

# Copy static files to destination, or create public directory
if [[ -d static ]]; then
    cp -LR static public || bail 9 "Error: Failed to copy static/ to public/."
else
    mkdir -p public || bail 10 "Error: Failed to create public/ directory."
fi

# Re-create directory hierarchy of content/ in destination
find -L content -type d |
    grep -v "^content\$" |
    cut -d'/' -f2- |
    while IFS= read -r sub
    do
        mkdir -p "public/$sub" || {
            echo "Error: Failed to create directory public/$sub" >&2
            exit 11
        }
    done

# To each file in content/, apply template (in parallel)
for pattern in "$@"
do
    # Read all matching files into an array
    mapfile -t sources < <(find -L content -type f -name "$pattern" | cut -d'/' -f2-)

    # Process each file in parallel
    for source in "${sources[@]}"; do
        [[ -z "$source" ]] && continue

        template=$(resolve_template "$source")

        if [[ -f "template/$template" ]]; then
            apply_once "$source" "template/$template" &
        fi
    done
done

# Wait for all background jobs to complete
wait
