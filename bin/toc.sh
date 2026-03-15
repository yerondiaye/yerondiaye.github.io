#!/usr/bin/env bash

sed -nE 's/.*<h3[^>]*id="([^"]+)"[^>]*>(.+)<\/h3>.*/<li><a href="#\1">\2<\/a><\/li>/p' "content/$CYC_FILE"
