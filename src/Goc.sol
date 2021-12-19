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
    mapping(uint => mapping(uint8 => Market)) moveMarketWinners;

    function getOutcomeReservesTokenIds(bytes32 _marketId) public returns (uint oToken0Id, uint oToken1Id){
        oToken0Id = uint(keccak256(abi.encode(_marketId, 0)));
        oToken1Id = uint(keccak256(abi.encode(_marketId, 1)));
    }

    function getMarketId(uint _gameId, uint16 _moveCount, uint24 _moveValue) public pure returns (bytes32){
        return keccak256(abi.encode(_gameId, _moveCount, _moveValue));
    }

    function createAndFundMarket(uint _gameId, uint24 _moveValue, address _creator) external {
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
        _market.yesProbabity = 5000;
        _market.prob0x10000 = calculate0Probx10000(_outcomeReserves);
        markets[_marketId] = _market;

        // update market leader
        if (moveMarketWinners[_gameId][_move].prob0x10000 < _market.prob0x10000){
            moveMarketWinners[_gameId][_move] = _market;
        }

        // hurray market created; TODO emit event
    }

    function calculate0Probx10000(OutcomeReserves memory _outcomeReserves) internal returns (uint16 prob){
        prob = _outcomeReserves.reserve0 * 10000 / (_outcomeReserves.reserve0 + _outcomeReserves.reserve1);
    }

    function updateMoveMarketLeader(uint _gameId, uint _marketId) internal {
        uint prob0x10000 = calculate0Probx10000(_outcomeReserves);
    }

}