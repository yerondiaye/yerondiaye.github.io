#!/bin/sh

set -eu

file="content/$CYC_FILE"
mfile="meta/$CYC_FILE"

git log -n 1 --pretty=format:%ad --date=format:'%Y-%m-%d' -- "$file"
