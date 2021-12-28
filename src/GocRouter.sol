// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./libraries/GameHelpers.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/Math.sol";
import "./Goc.sol";
import "./interfaces/IGocDataTypes.sol";
import "./interfaces/IERC1155.sol";

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
        Goc _goc = goc;
        address cToken = _goc.cToken();

        // create market & fund it
        TransferHelper.safeTransferFrom(cToken, msg.sender, address(goc), fundingAmount);
        _goc.createAndFundMarket(_moveValue, msg.sender);

        // place the bet
        uint256 a0;
        uint256 a1;
        if (_for == 0) a0 = Math.getTokenAmountToBuyWithAmountC(0, 1, fundingAmount, fundingAmount, betAmount);
        if (_for == 1) a1 = Math.getTokenAmountToBuyWithAmountC(0, 0, fundingAmount, fundingAmount, betAmount);
        TransferHelper.safeTransferFrom(cToken, msg.sender, address(goc), betAmount);
        _goc.buy(a0, a1, msg.sender, _moveValue);
    }   
    
    function buyMinTokensForExactCTokens(uint256 amountOutToken0Min, uint256 amountOutToken1Min, uint256 amountInC,uint256 fixedTokenIndex, uint256 moveValue) external {
        require(fixedTokenIndex < 2, "INVALID INDEX");
        Goc _goc = goc;
        
        // check invariance holds
        (uint256 r0, uint256 r1) = _goc.outcomeReserves(moveValue);
        uint256 a0; 
        uint256 a1;
        if (fixedTokenIndex == 0){
            a1 = Math.getTokenAmountToBuyWithAmountC(amountOutToken0Min, 0, r0, r1, amountInC);
        }else if (fixedTokenIndex == 1){
            a0 = Math.getTokenAmountToBuyWithAmountC(amountOutToken1Min, 1, r0, r1, amountInC);
        }
        require(a0 >= amountOutToken0Min && a1 >= amountOutToken1Min, "TRADE: INVALID");
        
        // buy
        TransferHelper.safeTransfer(_goc.cToken(), address(_goc), amountInC);
        _goc.buy(a0, a1, msg.sender, moveValue);
    }

    // sell
    function sellExactTokensForMinCTokens(uint256 amountInToken0, uint256 amountInToken1, uint256 amountOutTokenCMin, uint256 moveValue) external  {
        Goc _goc = goc;

        // check invariance holds
        (uint256 r0, uint256 r1) = _goc.outcomeReserves(moveValue);
        uint a = Math.getAmountCBySellTokens(amountInToken0, amountInToken1, r0, r1);
        require(a >= amountOutTokenCMin, "TRADE: INVALID");

        // sell
        (uint256 t0, uint256 t1) = _goc.getOutcomeReservesTokenIds(moveValue);
        IERC1155(address(_goc)).safeTransferFrom(msg.sender, address(_goc), t0, amountInToken0, '');
        IERC1155(address(_goc)).safeTransferFrom(msg.sender, address(_goc), t1, amountInToken1, '');
        _goc.sell(a, msg.sender, moveValue);
    }  

    // redeemBet
    function redeemBet
    
    // redeemWin

}