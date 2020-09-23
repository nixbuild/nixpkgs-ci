#!/bin/sh

count="$1"

jq -r 'keys[] as $k | "\"\($k)\" \"\(.[$k])\""' \
  | shuf -n "$count" \
  | xargs -P0 -I ARGS /bin/sh -c "build-drv ARGS"
