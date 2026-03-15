#!/bin/sh

set -eu

# The following is useful with web servers like nginx that can
# directly serve gzipped files. See nginx's "gzip_static" directive.

# find public -type f |
#     while IFS= read -r file
#     do
#         gzip < "$file" > "$file.gz" &
#     done
#
# wait

# Upload website to server.

# chmod -R a+r public # this line may be necessary, but it could be dangerous
# mv public example.com
# rsync --delete --checksum -az example.com YOURSERVERHERE:/srv/http
# rm -rf example.com

# Etc.
