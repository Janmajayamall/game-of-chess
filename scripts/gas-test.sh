#!/usr/bin/env bash

set -eo pipefail

Goc=0x5d24A59077844FAB0ef62423496026d5ab2D87F3
GocRouter=0x61631f6D09985F760bb436275d34c09e79293bA5

# create new game
estimate=$(seth estimate $Goc "newGame()")
echo $estimate
seth send $Goc "newGame()" --gas $estimate

# mint max uint256 token balance
# estimate=$(seth estimate $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256))
# seth send $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256) --gas $estimate