#!/usr/bin/env bash

set -eo pipefail

Goc=0xf57e96FBF6BeB0BcE1aB80faef921C890F1FcD79
GocRouter=0x3ba53672352E30158097534e91Ce165df1E015Ab

# create new game
estimate=$(seth estimate $Goc "newGame()")
seth send $Goc "newGame()" --gas $estimate

# mint max uint256 token balance
# estimate=$(seth estimate $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256))
# seth send $TEST_TOKEN_ADDRESS "mint(address,uint256)" $DEPLOYER $(seth --max-uint 256) --gas $estimate