#!/usr/bin/env bash

set -eo pipefail

# Goc=0x8701978d5598a91Fb590cfaA1fa9764564E5f087
# GocRouter=0xB379f451F5DC50943f6F260323FBE03D9532a431
Goc=0x35e1761E0De1E2142E5A97AA85C27D713f8Af104
GocRouter=0x0FE01B284904Df107807F991A76Aa4Ef21D710fE

# create new game
# estimate=$(seth estimate $Goc "newGame()")
# echo $estimate
# seth send $Goc "newGame()" --gas $estimate

# mint max uint256 token balance
# echo $TEST_TOKEN_ADDRESS
# estimate=$(seth estimate $TEST_TOKEN_ADDRESS "mint(address,uint256)" $ETH_FROM $(seth --max-uint 256))
# seth send $TEST_TOKEN_ADDRESS "mint(address,uint256)" $ETH_FROM $(seth --max-uint 256) --gas $estimate

# estimate=$(seth estimate $TEST_TOKEN_ADDRESS "approve(address,uint256)" $GocRouter $(seth --max-uint 256))
# echo $estimate
# seth send $TEST_TOKEN_ADDRESS "approve(address,uint256)" $GocRouter $(seth --max-uint 256) --gas $estimate

# estimate=$(seth estimate $GocRouter "createFundBetOnMarket(uint256,uint256,uint256,uint256)" 68720527920 $(seth --to-wei 1 eth) $(seth --to-wei 1 eth) 1)
# echo $estimate
# seth estimate $GocRouter "createFundBetOnMarket(uint256,uint256,uint256,uint256)" 68720527920 $(seth --to-wei 1 eth) $(seth --to-wei 1 eth) 1
