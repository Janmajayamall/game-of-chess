// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "ds-test/test.sol";
import "./interfaces/IChess.sol";
import "./interfaces/IERC20.sol";
import "./ERC1155.sol";
import "./Game.sol";

contract Goc is Game, ERC1155, DSTest {

    mapping(uint256 => Market) markets;
    mapping(uint256 => address) marketCreators;
    mapping(uint256 => OutcomeReserves) outcomeReserves;
    uint256 cReserves;

    address constant cToken = address(0);

    /**
        MOVE MANAGER STUFF
    */
    // for every move, store market with highest probability 
    // gameId => moveCount => Market
    mapping(uint16 => mapping(uint16 => uint256)) leadingMarketForMoves;
    // gameId => lastMoveTimestamp
    mapping(uint16 => uint) gamesLastMoveTimestamp;

    function getOutcomeReservesTokenIds(uint256 _moveValue) public returns (uint oToken0Id, uint oToken1Id){
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
        require(_gameState.state != 0, "Invalid GameId");

        // decode move
        Move memory _move = decodeMove(_moveValue, _gameState.bitboards);
        // check move validity against current game state
        require(isMoveValid(_gameState, _move), "Invalid move");

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

        // hurray market created; TODO emit event
    }

    // add buy
    function buy(uint amount0, uint amount1, address to, uint256 _moveValue) external {
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
        outcomeReserves[_moveValue] = _outcomeReserves;
    }

    // add sell
    function sell(uint amountOut, address to, uint256 _moveValue) external {
        require(marketCreators[_moveValue] != address(0), "Market Invalid");

        // market should not have expired
        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        uint16 _moveCount = decodeMoveCountFromMoveValue(_moveValue);
        {
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

        // check invariance
        uint nReserve0 = _outcomeReserves.reserve0 + amount0In - amountOut;
        uint nReserve1 = _outcomeReserves.reserve1 + amount1In - amountOut;
        require((nReserve0 * nReserve1) >= (_outcomeReserves.reserve0 * _outcomeReserves.reserve1), "ERR: INV");

        // update reserves
        _outcomeReserves.reserve0 = nReserve0;
        _outcomeReserves.reserve1 = nReserve1;
        outcomeReserves[_moveValue] = _outcomeReserves;
    }

    // // redeem 
    // function redeem(bytes32 _marketId) external {
    //     Market memory _market = markets[_marketId];
    //     require(_market.creator == address(0), "Market invalid");

    //     GameState memory _gameState = gamesState[_market.gameId];
    //     Market memory moveMarketWinner = moveMarketWinners[_market.gameId][_market.moveCount];

    //     require(_gameState.state == 2 || _gameState.moveCount + 1 > _market.moveCount);
    // }

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
        prob = uint16(_outcomeReserves.reserve0 * 10000 / (_outcomeReserves.reserve0 + _outcomeReserves.reserve1));
    }

    // function makeMove(uint32 _gameId) external {
    //     uint16 moveCount = gamesState[_gameId].moveCount;
    //     Market memory winnerMarket = moveMarketWinners[_gameId][moveCount+1];
    //     require(winnerMarket.creator != address(0), "0 move markets");

    //     // Time elapsed since last move should be atleast 24 hours
    //     uint lastMoveTimestamp = gamesLastMoveTimestamp[_gameId];
    //     require(block.timestamp - lastMoveTimestamp > 24*60*60, "Time Err");

    //     // apply move to the game state
    //     applyMove(_gameId, winnerMarket.moveValue);

    //     // update timestamp
    //     gamesLastMoveTimestamp[_gameId] = block.timestamp;
    // }








    function test_decodeMove() public {
        uint w = 2737 & 63;
        // emit log_named_uint("w ", w); 
        // Move memory _move = decodeMove(2737, [
        //     // initial black pos
        //     65280,
        //     66,
        //     36,
        //     129,
        //     8,
        //     16,
        //     // initial white pos
        //     71776119061217280,
        //     4755801206503243776,
        //     2594073385365405696,
        //     9295429630892703744,
        //     576460752303423488,
        //     1152921504606846976
        // ]);
    }

    mapping(uint => uint) single;
    mapping(uint => mapping (uint => uint)) double;
    mapping(uint => mapping (uint => mapping (uint => uint))) triple;

    function setUp() public {
        single[9] = 10;
        double[9][9] = 10;
        triple[9][9][9] = 10;
    }

    function test_single() public {
        uint v = single[9];
    }

    function test_double() public {
        uint v = double[9][9];
    }

    function test_triple() public {
        uint v = triple[9][9][9];
    }
}