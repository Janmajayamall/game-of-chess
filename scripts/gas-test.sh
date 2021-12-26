#!/usr/bin/env bash

set -eo pipefail

Goc=0x4C42B00757FaE8aeE5F09a6b5363B6f476f7201d
GocRouter=0x474F8a2E737f01D4A659c3beB04029BA73ED77C9

# create new game
estimate=$(seth estimate $Goc "newGame()")
echo $estimate
seth send $Goc "newGame()" --gas $estimate

# mint max uint256 token balance
# estimate=$(seth estimate $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256))
# seth send $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256) --gas $estimate