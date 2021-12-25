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

    function getGameFenString(uint16 _gameId) external view returns (string memory){
        return GameHelpers.parseGameStateToFenString(goc.getGameState(_gameId));
    }

    function getGameState(uint16 _gameId) external view returns (IGocDataTypes.GameState memory gameState) {
        gameState = goc.getGameState(_gameId);
    }

    function getGameIdFromMoveValue(uint256 _moveValue) external pure returns(uint16 _gameId){
        _gameId = GameHelpers.decodeGameIdFromMoveValue(_moveValue);
    }

    function getMoveCountFromMoveValue(uint256 _moveValue) external pure returns(uint16 _moveCount){
        _moveCount = GameHelpers.decodeMoveCountFromMoveValue(_moveValue);
    }

    function getMoveMetadataFromMoveValue(uint256 _moveValue) external view returns(IGocDataTypes.MoveMetadata memory _moveMetadata){
        uint16 _gameId = GameHelpers.decodeGameIdFromMoveValue(_moveValue);
        _moveMetadata = GameHelpers.decodeMoveMetadataFromMoveValue(_moveValue, goc.getGameState(_gameId).bitboards);
    }

}