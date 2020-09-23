#!/usr/bin/env bash

set -eo pipefail

nix eval --json .#jobs \
  | jq 'to_entries | map(select(.value != null)) | from_entries' \
  > derivations.json
