#!/usr/bin/env bash

set -eo pipefail

Goc=0xaCB7E9956Adb88F631403040cA34b1A82a067EDA
GocRouter=0xc78523573CC6857EfAb5AE92AFFB9809750314E5

# create new game
estimate=$(seth estimate $Goc "newGame()")
seth send $Goc "newGame()" --gas $estimate

# mint max uint256 token balance
# estimate=$(seth estimate $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256))
# seth send $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256) --gas $estimate