#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy.
# Goc=$(deploy Goc $TEST_TOKEN_ADDRESS)
Goc=0x4C42B00757FaE8aeE5F09a6b5363B6f476f7201d
GocRouter=$(deploy GocRouter $Goc)

log "Goc deployed at:" $Goc
log "GocRouter deployed at:" $GocRouter
