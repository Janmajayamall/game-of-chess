#!/usr/bin/env bash

set -eo pipefail

# import the deployment helpers
. $(dirname $0)/common.sh

# Deploy.
# Token=$(deploy TestToken)
Goc=$(deploy Goc $TEST_TOKEN_ADDRESS)
GocRouter=$(deploy GocRouter $Goc)

# log "Token deployed at:" $Token
log "Goc deployed at:" $Goc
log "GocRouter deployed at:" $GocRouter
