#!/usr/bin/env bash

set -euo pipefail

# Validate CYC_FILE is set
if [[ -z "${CYC_FILE:-}" ]]; then
    echo "Error: CYC_FILE environment variable is not set" >&2
    exit 1
fi

file="content/$CYC_FILE"
mfile="meta/$CYC_FILE"

# Check if the content file exists
if [[ ! -f "$file" ]]; then
    echo "Error: Content file $file does not exist" >&2
    exit 2
fi

if [[ ! -f "$mfile.utime" ]]; then
    # Check if bin/mtime exists and is executable
    if [[ ! -x "bin/mtime" ]]; then
        echo "Error: bin/mtime not found or not executable" >&2
        exit 3
    fi

    bin/mtime "$file" || {
        echo "Error: Failed to get modification time for $file" >&2
        exit 4
    }

    # Alternatively,
    # git log -n 1 --pretty=format:%ad \
    #   --date=format:'%Y-%m-%d %H:%M' -- "$file"
else
    cat "$mfile.utime" || {
        echo "Error: Failed to read $mfile.utime" >&2
        exit 5
    }
fi
