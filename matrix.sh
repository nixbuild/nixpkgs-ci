#!/usr/bin/env bash

jq --argjson w $WORKERS -nc '{ workers: [$w], worker_idx: [range(0,$w)]}'
