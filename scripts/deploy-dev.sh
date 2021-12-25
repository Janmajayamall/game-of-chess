#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy.
Goc=$(deploy Goc )
GocRouter=$(deploy GocRouter $Goc $TEST_TOKEN_ADDRESS)

log "Goc deployed at:" $Goc
log "GocRouter deployed at:" $GocRouter
