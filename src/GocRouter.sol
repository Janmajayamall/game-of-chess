// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libraries/GameHelpers.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/Math.sol";
import "./Goc.sol";
import "./interfaces/IGocDataTypes.sol";

contract GocRouter {

    Goc public goc;

    constructor(address gocAddress){
        goc = Goc(gocAddress);
    }

    function getGameState(uint16 _gameId) external view returns (IGocDataTypes.GameState memory gameState) {
        gameState = goc.getGameState(_gameId);
    }

    function getMoveMetadataFromMoveValue(uint256 _moveValue) external view returns(IGocDataTypes.MoveMetadata memory _moveMetadata){
        uint16 _gameId = GameHelpers.decodeGameIdFromMoveValue(_moveValue);
        _moveMetadata = GameHelpers.decodeMoveMetadataFromMoveValue(_moveValue, goc.getGameState(_gameId).bitboards);
    }

    function createFundBetOnMarket(uint256 _moveValue, uint256 fundingAmount, uint256 betAmount, uint256 _for) external {  
        address cToken = goc.cToken();

        // create market & fund it
        TransferHelper.safeTransferFrom(cToken, msg.sender, address(goc), fundingAmount);
        goc.createAndFundMarket(_moveValue, msg.sender);

        // place the bet
        uint256 a0;
        uint256 a1;
        if (_for == 0) a0 = Math.getTokenAmountToBuyWithAmountC(0, 1, fundingAmount, fundingAmount, betAmount);
        if (_for == 1) a1 = Math.getTokenAmountToBuyWithAmountC(0, 0, fundingAmount, fundingAmount, betAmount);
        TransferHelper.safeTransferFrom(cToken, msg.sender, address(goc), betAmount);
        goc.buy(a0, a1, msg.sender, _moveValue);
    }   

    buy

    sell

    redeemBet
    
    redeemWin

}