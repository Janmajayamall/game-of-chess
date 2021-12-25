// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "ds-test/test.sol";
import "./interfaces/IChess.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IGocEvents.sol";
import "./ERC1155.sol";
import "./Game.sol";

contract Goc is Game, ERC1155, IGocEvents {

    mapping(uint256 => address) marketCreators;

    uint256 cReserves;
    mapping(uint256 => OutcomeReserves) outcomeReserves;

    mapping(uint256 => bool) chosenMoveValues;
    mapping(uint16 => uint) gamesLastMoveTimestamp;

    address immutable cToken;

    address manager;

    constructor(address _cToken) {
        manager = msg.sender;
        cToken = _cToken;
    }

    function getOutcomeReservesTokenIds(uint256 _moveValue) public pure returns (uint oToken0Id, uint oToken1Id){
        oToken0Id = uint(keccak256(abi.encode(_moveValue, 0)));
        oToken1Id = uint(keccak256(abi.encode(_moveValue, 1)));
    }

    function getMarketId(uint56 _moveValue) public pure returns (bytes32){
        return keccak256(abi.encode(_moveValue));
    }

    function createAndFundMarket(uint256 _moveValue, address _creator) external {
        // check game is in valid state
        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        GameState memory _gameState = gamesState[_gameId];
        require(_gameState.state == 1, "Invalid move");

        {
            // decode move
            MoveMetadata memory _moveMetadata = decodeMoveMetadataFromMoveValue(_moveValue, _gameState.bitboards);
            // check move validity against current game state
            require(isMoveValid(_gameState, _moveMetadata), "Invalid move");
        }

        // check whether move already exists
        require(marketCreators[_moveValue] == address(0), "Market exists!");

        // fundingAmount
        address _cToken = cToken;
        uint256 _cReserves = cReserves;
        uint fundingAmount = IERC20(_cToken).balanceOf(address(this)) - _cReserves;
        cReserves = _cReserves + fundingAmount;

        // set outcome reserves
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_moveValue);
        _mint(address(this), oToken0Id, fundingAmount, '');
        _mint(address(this), oToken1Id, fundingAmount, '');
        OutcomeReserves memory _outcomeReserves;
        _outcomeReserves.reserve0 = fundingAmount;
        _outcomeReserves.reserve1 = fundingAmount;
        outcomeReserves[_moveValue] = _outcomeReserves;
        
        // set market creator
        marketCreators[_moveValue] = _creator;

        require(fundingAmount > 0, "Funding: 0");

        emit MarketCreated(_moveValue, _creator);
    }

    function buy(uint amount0, uint amount1, address to, uint256 _moveValue) external {
        // market exists
        require(marketCreators[_moveValue] != address(0), "Market Invalid");

        // market should not have expired
        {
            uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
            uint16 _moveCount = decodeMoveCountFromMoveValue(_moveValue);
            GameState memory _gameState = gamesState[_gameId];
            require(_gameState.moveCount + 1 == _moveCount, "Market expired");
        }

        // amountIn
        address _cToken = cToken;
        uint256 _cReserves = cReserves;
        uint amountIn = IERC20(_cToken).balanceOf(address(this)) - _cReserves;
        cReserves = _cReserves + amountIn;
        
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_moveValue);
        OutcomeReserves memory _outcomeReserves = outcomeReserves[_moveValue];

        // mint outcome tokens
        _mint(address(this), oToken0Id, amountIn, '');
        _mint(address(this), oToken1Id, amountIn, '');

        // optimistically transfer amount0 & amount1
        safeTransferFrom(address(this), to, oToken0Id, amount0, '');
        safeTransferFrom(address(this), to, oToken1Id, amount1, '');

        // check invariance
        uint nReserve0 = _outcomeReserves.reserve0 + amountIn - amount0;
        uint nReserve1 = _outcomeReserves.reserve1 + amountIn - amount1;
        require((nReserve0*nReserve1) >= (_outcomeReserves.reserve0*_outcomeReserves.reserve1), "ERR: INV");

        // update reserves
        _outcomeReserves.reserve0 = nReserve0;
        _outcomeReserves.reserve1 = nReserve1;
        outcomeReserves[_moveValue] = _outcomeReserves;

        emit OutcomeBought(_moveValue, to, amountIn, amount0, amount1);
    }

    function sell(uint amountOut, address to, uint256 _moveValue) external {
        // market exists
        require(marketCreators[_moveValue] != address(0), "Market Invalid");

        // market should not have expired
        {
            uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
            uint16 _moveCount = decodeMoveCountFromMoveValue(_moveValue);
            GameState memory _gameState = gamesState[_gameId];
            require(_gameState.moveCount + 1 == _moveCount, "Market expired");
        }

        // optimistically transfer amountOut
        address _cToken = cToken;
        IERC20(_cToken).transfer(to, amountOut);
        cReserves -= amountOut;

        // amount0In and amount1In
        OutcomeReserves memory _outcomeReserves = outcomeReserves[_moveValue];
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_moveValue);
        uint amount0In = balanceOf(address(this), oToken0Id) - _outcomeReserves.reserve0;
        uint amount1In = balanceOf(address(this), oToken1Id) - _outcomeReserves.reserve1;

        // burn outcome tokens equivalent to amount out
        _burn(address(this), oToken0Id, amountOut);
        _burn(address(this), oToken1Id, amountOut);

        // check invariance
        uint nReserve0 = _outcomeReserves.reserve0 + amount0In - amountOut;
        uint nReserve1 = _outcomeReserves.reserve1 + amount1In - amountOut;
        require((nReserve0 * nReserve1) >= (_outcomeReserves.reserve0 * _outcomeReserves.reserve1), "ERR: INV");

        // update reserves
        _outcomeReserves.reserve0 = nReserve0;
        _outcomeReserves.reserve1 = nReserve1;
        outcomeReserves[_moveValue] = _outcomeReserves;

        emit OutcomeSold(_moveValue, to, amountOut, amount0In, amount1In);
    }
 
    function redeemWins(uint256 _moveValue, address to) external {
        require(marketCreators[_moveValue] != address(0), "Market invalid");

        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        GameState memory _gameState = gamesState[_gameId];
        bool isChosenMove = chosenMoveValues[_moveValue];
        require(_gameState.state == 2 && isChosenMove == true, "Invalid State");

        // amount0In and amount1In
        OutcomeReserves memory _outcomeReserves = outcomeReserves[_moveValue];
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_moveValue);
        uint amount0In = balanceOf(address(this), oToken0Id) - _outcomeReserves.reserve0;
        uint amount1In = balanceOf(address(this), oToken1Id) - _outcomeReserves.reserve1;

        // burn received tokens
        _burn(address(this), oToken0Id, amount0In);
        _burn(address(this), oToken1Id, amount1In);

        // win amount
        uint winAmount;
        uint side = _moveValue >> 17 & 1;
        if (_gameState.winner == 0 && side == 0){
            winAmount = amount0In;
        }else if (_gameState.winner == 1 && side == 1){
            winAmount = amount1In;
        }else if (_gameState.winner == 2){
            winAmount = amount0In/2 + amount1In/2;
        }

        // transfer win amount and update cReservers
        IERC20(cToken).transfer(to, winAmount);
        cReserves -= winAmount;

        emit WinningRedeemed(_moveValue, to);
    }

    function redeem(uint256 _moveValue, address to) external {
        require(marketCreators[_moveValue] != address(0), "Market invalid");

        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        uint16 _moveCount = decodeMoveCountFromMoveValue(_moveValue);
        GameState memory _gameState = gamesState[_gameId];
        bool isChosenMove = chosenMoveValues[_moveValue];
        require(
            (_gameState.moveCount + 1 > _moveCount || _gameState.state == 2) 
            && isChosenMove == false                
        );

        // amount0In and amount1In
        OutcomeReserves memory _outcomeReserves = outcomeReserves[_moveValue];
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_moveValue);
        uint amount0In = balanceOf(address(this), oToken0Id) - _outcomeReserves.reserve0;
        uint amount1In = balanceOf(address(this), oToken1Id) - _outcomeReserves.reserve1;

        // burn received tokens
        _burn(address(this), oToken0Id, amount0In);
        _burn(address(this), oToken1Id, amount1In);

        // amountOut
        uint amountOut = amount0In + amount1In;
        IERC20(cToken).transfer(to, amountOut);
        cReserves -= amountOut;

        emit BetRedeemed(_moveValue, to);
    }

    // manager functions 
    // TODO look for an efficient way for storing sorted list of
    // YES probabilty of every market for each moveCount.
    // Rn, the manager is trusted with calling makeMove 
    // with the moveValue (i.e. marketId) that has highest YES
    // probability among the rest of the markets for the same 
    // move count. This isn't ideal,, since a single mistake
    // by manager would destroy the enitre purpose of this 
    // contract. 
    function makeMove(uint256 _moveValue) external {
        require(manager == msg.sender, "Auth ERR");
        require(marketCreators[_moveValue] != address(0), "Invalid Market");

        // Time elapsed since last move should be atleast 24 hours
        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        uint lastMoveTimestamp = gamesLastMoveTimestamp[_gameId];
        // TODO switch time diffrence back to 24 hrs from 60 seconds
        require(block.timestamp - lastMoveTimestamp > 60, "Time Err");

        // apply move to the game state
        applyMove(_moveValue);

        // update timestamp
        gamesLastMoveTimestamp[_gameId] = block.timestamp;

        // set _moveValue as chosen move
        chosenMoveValues[_moveValue] = true;

        emit MoveMade(_moveValue);
    }

    function oddCaseDeclareOutcome(uint256 outcome, uint256 _moveValue) external {
        require(msg.sender == manager, "Auth ERR");
        _oddCaseDeclareOutcome(outcome, _moveValue);
    }

    function newGame() external {
        require(msg.sender == manager, "Auth ERR");
        uint16 gameIndex = _newGame();
        // set timestamp for first move
        gamesLastMoveTimestamp[gameIndex] = block.timestamp;
        emit GameCreated(gameIndex);
    }

    function updateManager(address to) external {
        require(msg.sender == manager, "Auth ERR");
        manager = to;
    }
}

/**
Just thinking - 
1. Should I add NFT per winning move? 
    just to motivate people to elect new moves? 
 */

 /**
 1. Parse FEN and game & check game transition
 2. Work on NFT 
  */
