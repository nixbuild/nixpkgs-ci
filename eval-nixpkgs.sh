#!/usr/bin/env bash

# This duplicates the number of evaluations and runs two evals in parallel,
# since we have 2 CPUs

set -euo pipefail

WORKERS="$1"
WORKER_IDX="$2"

W=$((2 * WORKERS))

echo -e "$((2 * WORKER_IDX))\n$((2 * WORKER_IDX + 1))" | xargs -P2 -I W_IDX \
  bash -c "nix eval --json --apply 'f: f $W W_IDX' ..#jobSubset | jq -c '.[]'"
