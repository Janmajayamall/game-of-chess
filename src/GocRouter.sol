// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libraries/GameHelpers.sol";
import "./Goc.sol";
import "./interfaces/IGocDataTypes.sol";

contract GocRouter {

    Goc goc;

    constructor(address gocAddress){
        goc = Goc(gocAddress);
    }

    function getGameBoardString(uint16 _gameId) external returns (string memory){
        IGocDataTypes.GameState memory gameState = goc.getGameState(_gameId);
        return GameHelpers.parseBitboardsToString(gameState.bitboards);
    }

    function getGameState(uint16 _gameId) external returns (IGocDataTypes.GameState memory gameState) {
        gameState = goc.getGameState(_gameId);
    }

}