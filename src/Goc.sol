// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
// import "ds-test/test.sol";
import "./interfaces/IChess.sol";
import "./interfaces/IERC20.sol";
import "./ERC1155.sol";
import "./Game.sol";

contract Goc is Game, ERC1155 {

    mapping(bytes32 => Market) markets;

    address constant cToken = address(0);
    uint256 cReserves;
    mapping(bytes32 => OutcomeReserves) outcomeReserves;

    /**
        MOVE MANAGER STUFF
    */
    // for every move, store market with highest probability 
    // gameId => moveCount => Market
    mapping(uint => mapping(uint16 => Market)) moveMarketWinners;
    // gameId => lastMoveTimestamp
    mapping(uint => uint) gamesLastMoveTimestamp;

    function getOutcomeReservesTokenIds(bytes32 _marketId) public returns (uint oToken0Id, uint oToken1Id){
        oToken0Id = uint(keccak256(abi.encode(_marketId, 0)));
        oToken1Id = uint(keccak256(abi.encode(_marketId, 1)));
    }

    function getMarketId(uint _gameId, uint16 _moveCount, uint24 _moveValue) public pure returns (bytes32){
        return keccak256(abi.encode(_gameId, _moveCount, _moveValue));
    }

    function createAndFundMarket(uint32 _gameId, uint24 _moveValue, address _creator) external {
        GameState memory _gameState = gamesState[_gameId];

        // check move validity against current game state
        Move memory _move = decodeMove(_moveValue, _gameState.bitboards);
        require(isMoveValid(_gameState, _move), "Invalid move");

        bytes32 _marketId = getMarketId(_gameId, _gameState.moveCount + 1, _moveValue);

        // check move does not already exists
        require(markets[_marketId].creator == address(0), "Move exists");

        // create a market
        address _cToken = cToken;
        uint256 _cReserves = cReserves;
        uint fundingAmount = IERC20(_cToken).balanceOf(address(this)) - _cReserves;
        cReserves = _cReserves + fundingAmount;

        // set outcome reserves
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_marketId);
        _mint(address(this), oToken0Id, fundingAmount, '');
        _mint(address(this), oToken1Id, fundingAmount, '');
        OutcomeReserves _outcomeReserves;
        _outcomeReserves.reserve0 = fundingAmount;
        _outcomeReserves.reserve1 = fundingAmount;
        outcomeReserves[_marketId] = _outcomeReserves;
        
        // set market
        Market memory _market;
        _market.creator = _creator;
        _market.moveValue = _moveValue;
        _market.moveCount = _gameState.moveCount;
        _market.side = _gameState.side;
        _market.prob0x10000 = calculate0Probx10000(_outcomeReserves);
        _market.gameId = _gameId;
        markets[_marketId] = _market;

        // update market leader
        if (moveMarketWinners[_gameId][_move].prob0x10000 < _market.prob0x10000){
            moveMarketWinners[_gameId][_move] = _market;
        }

        require(fundingAmount > 0, "Funding: 0");

        // hurray market created; TODO emit event
    }

    // add buy
    function buy(uint amount0, uint amount1, address to, bytes32 _marketId) external {
        Market _market = markets[_marketId];
        require(_market.creator != address(0), "Market Invalid");

        // market should not have expired
        GameState _gameState = gamesState[_market.gameId];
        require(_gameState.moveCount + 1 == _market.moveCount, "Market expired");

        // amountIn
        address _cToken = cToken;
        uint256 _cReserves = cReserves;
        uint amountIn = IERC20(_cToken).balanceOf(address(this)) - _cReserves;
        cReserves = _cReserves + amountIn;
        
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_marketId);
        OutcomeReserves memory _outcomeReserves = outcomeReserves[_marketId];

        // mint outcome tokens
        _mint(address(this), oToken0Id, amountIn, '');
        _mint(address(this), oToken1Id, amountIn, '');

        // optimistically transfer
        safeTransferFrom(address(this), to, oToken0Id, amount0, '');
        safeTransferFrom(address(this), to, oToken1Id, amount1, '');

        // check invariance
        uint nReserve0 = _outcomeReserves.reserve0 + amountIn - amount0;
        uint nReserve1 = _outcomeReserves.reserve1 + amountIn - amount1;
        require((nReserve0*nReserve1) >= (_outcomeReserves.reserve0*_outcomeReserves.reserve1), "ERR: INV");

        // update reserves
        _outcomeReserves.reserve0 = nReserve0;
        _outcomeReserves.reserve1 = nReserve1;
        outcomeReserves[_marketId] = _outcomeReserves;

        // update market
        _market.prob0x10000 = calculate0Probx10000(_outcomeReserves);
        markets[_marketId] = _market;

        // update market leader
        if (moveMarketWinners[_market.gameId][_market.moveCount].prob0x10000 < _market.prob0x10000){
            moveMarketWinners[_market.gameId][_market.moveCount] = _market;
        }
    }

    // add sell
    function sell(uint amountOut, address to, bytes32 _marketId) external {
        Market _market = markets[_marketId];
        require(_market.creator != address(0), "Market Invalid");

        // market should not have expired
        GameState _gameState = gamesState[_market.gameId];
        require(_gameState.moveCount + 1 == _market.moveCount, "Market expired");

        // optimistically transfer amountOut
        address _cToken = cToken;
        IERC20(_cToken).transfer(to, amountOut);
        cReserves -= amountOut;

        // amount0In and amount1In
        OutcomeReserves memory _outcomeReserves = outcomeReserves[_marketId];
        (uint oToken0Id, uint oToken1Id) = getOutcomeReservesTokenIds(_marketId);
        uint amount0In = balanceOf(address(this), oToken0Id) - _outcomeReserves.reserve0;
        uint amount1In = balanceOf(address(this), oToken1Id) - _outcomeReserves.reserve1;

        // check invariance
        uint nReserve0 = _outcomeReserves.reserve0 + amount0In - amountOut;
        uint nReserve1 = _outcomeReserves.reserve1 + amount1In - amountOut;
        require((nReserve0 * nReserve1) >= (_outcomeReserves.reserve0 * _outcomeReserves.reserve1), "ERR: INV");

        // update reserves
        _outcomeReserves.reserve0 = nReserve0;
        _outcomeReserves.reserve1 = nReserve1;
        outcomeReserves[_marketId] = _outcomeReserves;

        // update market
        _market.prob0x10000 = calculate0Probx10000(_outcomeReserves);
        markets[_marketId] = _market;

        // update market leader
        if (moveMarketWinners[_market.gameId][_market.moveCount].prob0x10000 < _market.prob0x10000){
            moveMarketWinners[_market.gameId][_market.moveCount] = _market;
        }
    }

    // add redeem (for both - winning and market not being chosen as choice)
    /**
        Rouch sketch of redeem
        1. Only allow redeem if moveCount is old && market wasn't chosen
            OR 
           game has ended && ended in their favor
        2. 
     */

    // move manager functions
    function calculate0Probx10000(OutcomeReserves memory _outcomeReserves) internal returns (uint16 prob){
        prob = _outcomeReserves.reserve0 * 10000 / (_outcomeReserves.reserve0 + _outcomeReserves.reserve1);
    }

    function makeMove(uint32 _gameId) external {
        uint16 moveCount = gamesState[_gameId].moveCount;
        Market winnerMarket = moveMarketWinners[gameId][moveCount+1];
        require(winnerMarket.creator != address(0), "0 move markets");

        // Time elapsed since last move should be atleast 24 hours
        uint lastMoveTimestamp = gamesLastMoveTimestamp[gameId];
        require(block.timestamp - lastMoveTimestamp > 24*60*60, "Time Err");

        // apply move to the game state
        applyMove(_gameId, winnerMarket.moveValue);

        // update timestamp
        gamesLastMoveTimestamp[gameId] = block.timestamp;
    }

}