#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

Goc=$(spit_abi Goc)
GocRouter=$(spit_abi GocRouter)