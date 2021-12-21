// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "ds-test/test.sol";
import "./interfaces/IChess.sol";
import "./interfaces/IERC20.sol";
import "./ERC1155.sol";
import "./Game.sol";

contract Goc is Game, ERC1155, DSTest {

    mapping(uint256 => address) marketCreators;

    uint256 cReserves;
    mapping(uint256 => OutcomeReserves) outcomeReserves;

    mapping(uint256 => bool) chosenMoveValues;
    mapping(uint16 => uint) gamesLastMoveTimestamp;

    address constant cToken = address(0);

    address manager;

    // constructor(address _manager) {
    //     manager = _manager;
    // }

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

        // hurray market created; TODO emit event
    }

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
 
    function redeemWins(uint256 _moveValue, address to) external {
        require(marketCreators[_moveValue] != address(0), "Market invalid");

        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        GameState memory _gameState = gamesState[_gameId];
        bool isChosenMove = chosenMoveValues[_moveValue];
        require(_gameState.state == 2 && isChosenMove == true);

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
        uint side = _moveValue >> 19 & 1;
        if (_gameState.winner == 0 && side == 0){
            winAmount = amount0In;
        }else if (_gameState.winner == 1 && side == 1){
            winAmount = amount1In;
        }else if (_gameState.winner == 2){
            winAmount = amount0In + amount1In;
        }

        // transfer win amount and update cReservers
        IERC20(cToken).transfer(to, winAmount);
        cReserves -= winAmount;

        // emit redeemWins;
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

        // emit redeem
    }

    // manager functions 
    function makeMove(uint256 _moveValue) external {
        require(manager == msg.sender, "Auth ERR");
        require(marketCreators[_moveValue] != address(0), "Invalid Market");

        // Time elapsed since last move should be atleast 24 hours
        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        uint lastMoveTimestamp = gamesLastMoveTimestamp[_gameId];
        require(block.timestamp - lastMoveTimestamp > 24*60*60, "Time Err");

        // apply move to the game state
        applyMove(_moveValue);

        // update timestamp
        gamesLastMoveTimestamp[_gameId] = block.timestamp;

        // set _moveValue as chosen move
        chosenMoveValues[_moveValue] = true;

        // emit makeMove
    }

    

    // function test_decodeMove() public {
    //     uint w = 2737 & 63;
    //     // emit log_named_uint("w ", w); 
    //     // Move memory _move = decodeMove(2737, [
    //     //     // initial black pos
    //     //     65280,
    //     //     66,
    //     //     36,
    //     //     129,
    //     //     8,
    //     //     16,
    //     //     // initial white pos
    //     //     71776119061217280,
    //     //     4755801206503243776,
    //     //     2594073385365405696,
    //     //     9295429630892703744,
    //     //     576460752303423488,
    //     //     1152921504606846976
    //     // ]);
    // }

    // mapping(uint => uint) single;
    // mapping(uint => mapping (uint => uint)) double;
    // mapping(uint => mapping (uint => mapping (uint => uint))) triple;

    // function setUp() public {
    //     // single[9] = 10;
    //     // double[9][9] = 10;
    //     // triple[9][9][9] = 10;
    // }

    // function test_single() public {
    //     uint v = single[9];
    // }

    // function test_double() public {
    //     uint v = double[9][9];
    // }

    // function test_triple() public {
    //     uint v = triple[9][9][9];
    // }

    // taken from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Strings.sol#L15-L35
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    mapping(uint => uint) boardMap;

    function encodeMove(
        uint sourceSq, 
        uint targetSq, 
        uint promotedPiece,
        bool doublePushFlag,
        bool enpassantFlag,
        bool castleFlag,
        uint side,
        uint gameId,
        uint moveCount
    ) public pure returns (uint moveValue) {
        moveValue |= moveCount << 36;
        moveValue |= gameId << 20;
        moveValue |= side << 19;
        if (castleFlag == true){
            moveValue |= 1 << 18;
        }
        if (enpassantFlag == true){
            moveValue |= 1 << 17;
        }
        if (doublePushFlag == true){
            moveValue |= 1 << 16;
        }
        moveValue |= promotedPiece << 12;
        moveValue |= targetSq << 6;
        moveValue |= sourceSq;
    }

    function append(string memory a, string memory b) internal pure returns (string memory){
        return string(abi.encodePacked(a, b));
    }

    function printMove(uint _moveValue) internal {
        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        GameState memory _gameState = gamesState[_gameId];
        MoveMetadata memory moveMetadata = decodeMoveMetadataFromMoveValue(_moveValue, _gameState.bitboards);

        string memory p = "";
        p = append("\n Game ID: ", toString(_gameId));
        if (moveMetadata.side == 0){
            p = append(p, "\n Side: WHITE");
        }else{
            p = append(p, "\n Side: BLACK");
        }
        p = append(p, append("\n Move Count: ", toString(moveMetadata.moveCount)));
        p = append(p, append("\n Source Sq : ", toString(moveMetadata.sourceSq)));
        p = append(p, append("\n Target Sq : ", toString(moveMetadata.targetSq)));
        p = append(p, append("\n Move By Sq : ", toString(moveMetadata.moveBySq)));
        p = append(p, append("\n Source Piece : ", toString(uint(moveMetadata.sourcePiece))));
        if (uint(moveMetadata.moveFlag) == 0){
            p = append(p, "\n Flag: No Flag");
        }
        if (uint(moveMetadata.moveFlag) == 1){
            p = append(p, "\n Flag: Double Push");
        }
        if (uint(moveMetadata.moveFlag) == 2){
            p = append(p, "\n Flag: Enpassant");
        }
        if (uint(moveMetadata.moveFlag) == 3){
            p = append(p, "\n Flag: Castle");
        }
        if (uint(moveMetadata.moveFlag) == 4){
            p = append(p, "\n Flag: Pawn Promotion");
        }
        p = append(p, "\n");
        emit log_string(p);
    }

    event DF(bytes1 f, bool k, bytes d);

    function parsePGNMove(bytes memory move, uint side, uint64[12] memory bitboards) public {
        // pawn move
        uint len = move.length;
        if (move[move.length-1] == bytes1("+") || move[move.length-1] == bytes1("#")){
            len -= 1;
        }

        bytes memory sourceSqStr = bytes.concat(move[len-2], move[len-1]);

        if (len-2 != 0){

            if (move[len-3] == bytes1("x")){
                // remove attack signal
                len -= 1;
            }

            if (len-2 != 0){
                // check piece
                if (len-2 == 1){
                    // piece
                }else {
                    // 0th index - piece
                    // 1st index rank or file    
                }
            }else {
                // pawn move
            }

        }else{
            // pawn move
        }
    }

    function test_parsePGNToMoveValue() public {
        string memory pgnStr = "1. e3 e2 ";
        bytes memory pgnBytes = bytes(pgnStr);
        uint index = 0;
        while (index < pgnBytes.length){
            while(pgnBytes[index] != bytes1(".")){
                index += 1;
            }

            index += 2; // skip space

            // white move
            bytes memory whiteM;
            while (pgnBytes[index] != bytes1(" ")){
                whiteM = bytes.concat(whiteM, pgnBytes[index]);
                index += 1;
            }
            emit log_string(string(whiteM));

            index += 1; // skip space

            // collect black move 
            bytes memory blackM;
            while (pgnBytes[index] != bytes1(" ")){
                blackM = bytes.concat(blackM, pgnBytes[index]);
                index += 1;
            }
            emit log_string(string(blackM));


        }
        // for (uint256 index = 0; index < pgnBytes.length; index++) {
            
        // }
        assertTrue(false);

    }

    function tes_fdd() public {
        string memory sd = "1dwaiudnaiosaonsmaokm";
        bytes memory ass = bytes(sd);
        for (uint256 index = 0; index < ass.length; index++) {
            // emit log_uint(index);
            emit DF(ass[index], ass[index]==bytes1("d"), abi.encodePacked(ass[index]));
            // if (uint(ass[index])==uint(100)){
            //     emit log_uint(12);
            // }
            // string memory char = string(bytes(ass[index]));
            // emit log_string(char);
        }
        assertTrue(false);
    }

    function printBoard() public {
        newGame();

        // apply move
        uint _moveValue = encodeMove(
            50,
            42,
            0,
            false,
            false,
            false,
            0,
            1,
            1
        );
         uint _moveValue2 = encodeMove(
            8,
            24,
            0,
            true,
            false,
            false,
            1,
            1,
            2
        );

        uint _moveValue3 = encodeMove(
            60,
            62,
            0,
            false,
            false,
            true,
            0,
            1,
            3
        );

        printMove(_moveValue);
        printMove(_moveValue2);
        printMove(_moveValue3);
        applyMove(_moveValue);
        applyMove(_moveValue2);
        applyMove(_moveValue3);

        GameState memory gameState = gamesState[1];

        // make every index 64 for for overlapping indentification
        for (uint256 index = 0; index < 64; index++) {
            boardMap[index] = 12;
        }
       
        for (uint256 pIndex = 0; pIndex < 12; pIndex++) {
            uint64 board = gameState.bitboards[pIndex];
            for (uint256 index = 0; index < 64; index++) {
                if (board & (1 << index) != 0){
                    require(boardMap[index] == 12, "Invalid board");
                    boardMap[index] = pIndex;
                }
            }
        }
        string memory p = "";
        for (uint256 index = 0; index < 64; index++) {
            uint piece = boardMap[index];

            if (index%8 == 0){
                p = append(p, "\n");
            }

            if (piece == 0){
                p = append(p, unicode" ♙");
            } 
            if (piece == 1){
                p = append(p, unicode" ♘");
            }    
            if (piece == 2){
                p = append(p, unicode" ♗");
            }
            if (piece == 3){
                p = append(p, unicode" ♖");
            }
            if (piece == 4){
                p = append(p, unicode" ♕");
            }
            if (piece == 5){
                p = append(p, unicode" ♔");
            }
            if (piece == 6){
                p = append(p, unicode" ♟︎");
            }
            if (piece == 7){
                p = append(p, unicode" ♞");
            }
            if (piece == 8){
                p = append(p, unicode" ♝");
            }
            if (piece == 9){
                p = append(p, unicode" ♜");
            }
            if (piece == 10){
                p = append(p, unicode" ♛");
            }
            if (piece == 11){
                p = append(p, unicode" ♚");
            }
            if (piece == 12){
                p = append(p, unicode" .");
            }
        }
        p = append(p, "\n");

        emit log_string(p);

        // emit log_bytes(abi.encodePacked(uint(10)));

        // emit log_string(
        //     "dawdadwad \n "
        //     "dwadaddd \n"
        //     "this is yout  \n"
        // );
        assertTrue(false);   
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