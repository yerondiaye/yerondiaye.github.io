#!/usr/bin/env bash
# Outputs an <h2> whose text is extracted from meta/$CYC_FILE.title.
# Titles like "Yero Ndiaye: Research" yield "Research".

set -euo pipefail

title=$(tr -d '\n' < "content/$CYC_FILE.title")

if [[ "$title" == *": "* ]]; then
    printf '<h2 class="fw-semibold mb-4">%s</h2>\n' "${title#*: }"
fi
