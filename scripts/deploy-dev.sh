#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy.
Goc=$(deploy Goc $TEST_TOKEN_ADDRESS)
GocRouter=$(deploy GocRouter $Goc)

log "Goc deployed at:" $Goc
log "GocRouter deployed at:" $GocRouter
