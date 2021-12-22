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
        bool castleFlag,
        uint side,
        uint gameId,
        uint moveCount
    ) public pure returns (uint moveValue) {
        moveValue |= uint(moveCount << 36);
        moveValue |= (gameId << 20);
        moveValue |= (side << 17);
        if (castleFlag == true){
            moveValue |= (1 << 16);
        }
        moveValue |= (promotedPiece << 12);
        moveValue |= (targetSq << 6);
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

    function parsePiece(bytes1 piece, uint side) public returns (Piece p) {
        if (piece == bytes1("N")){
            if (side == 0){
                return Piece.N;
            }
            return Piece.n;
        }
        if (piece == bytes1("R")){
            if (side == 0){
                return Piece.R;
            }
            return Piece.r;
        }
        if (piece == bytes1("B")){
            if (side == 0){
                return Piece.B;
            }
            return Piece.b;
        }
        if (piece == bytes1("Q")){
            if (side == 0){
                return Piece.Q;
            }
            return Piece.q;
        }
        if (piece == bytes1("K")){
            if (side == 0){
                return Piece.K;
            }
            return Piece.k;
        }
    }

    function findPieceSq(Piece p, uint64[12] memory bitboards, uint targetSq, uint eR, uint eF) public returns (uint sq){
        uint64 sourceBoard = bitboards[uint(p)];
        uint64 targetBoard = uint64(1 << targetSq);
        uint64 blockboard = getBlockerboard(bitboards);

        // finding sqaures from where Piece p can reach target sq
        uint64 attackBoard;
        if (p == Piece.P || p == Piece.p){
            // note - getPawnAttacks returns the board consisting of squares
            // that are reachable by pawn if pawn is on targetSq. We need to find
            // the squares from which pawns can reach the targetSq, thus we inverse
            // sides in function call.
            attackBoard = getPawnAttacks(targetSq, p == Piece.P ? 1 : 0);
            // pawn attacks does not include straight moves, thus adding them separately
            if (p == Piece.P){
                if (targetBoard << 16 != 0) attackBoard |= targetBoard << 16;
                if (targetBoard << 8 != 0) attackBoard |= targetBoard << 8;
            }else if (p == Piece.p){
                if (targetBoard >> 16 != 0) attackBoard |= targetBoard >> 16;
                if (targetBoard >> 8 != 0) attackBoard |= targetBoard >> 8;
            }
        }
        if (p == Piece.K || p == Piece.k){
            attackBoard = getKingAttacks(targetSq);
        }
        if (p == Piece.N || p == Piece.n){
            attackBoard = getKnightAttacks(targetSq);
        }
        if (p == Piece.R || p == Piece.r){
            attackBoard = getRookAttacks(targetSq, blockboard);
        }
        if (p == Piece.B || p == Piece.b){
            attackBoard = getBishopAttacks(targetSq, blockboard);
        }
        if (p == Piece.Q || p == Piece.q){
            attackBoard = getRookAttacks(targetSq, blockboard);
            attackBoard |= getBishopAttacks(targetSq, blockboard);
        }
        for (uint256 index = 0; index < 64; index++) {      
            if (sourceBoard & (1 << index) != 0){
                uint64 newBoard = uint64(1 << index);
                
                if (attackBoard & newBoard > 0){
                    emit log_named_uint("index  insisde",index);
                    if (eR != 8 && index / 8 == eR){
                        sq = index;
                    }else if (eF != 8 && index % 8 == eF){
                        sq = index;
                    }else {
                        sq = index;
                    }
                }
            }
        }
    }

    function parseRankStr(bytes1 rank) public returns (uint r){
        r = 8;
        if (rank == bytes1("1")){
            r = 7;
        }
        if (rank == bytes1("2")){
            r = 6;
        }
        if (rank == bytes1("3")){
            r = 5;
        }
        if (rank == bytes1("4")){
            r = 4;
        }
        if (rank == bytes1("5")){
            r = 3;
        }
        if (rank == bytes1("6")){
            r = 2;
        }
        if (rank == bytes1("7")){
            r = 1;
        }
        if (rank == bytes1("8")){
            r = 0;
        }
    }

    function parseFileStr(bytes1 file) public returns (uint f){
        f = 8;
        if (file == bytes1("a")){
            f = 0;
        }
        if (file == bytes1("b")){
            f = 1;
        }
        if (file == bytes1("c")){
            f = 2;
        }
        if (file == bytes1("d")){
            f = 3;
        }
        if (file == bytes1("e")){
            f = 4;
        }
        if (file == bytes1("f")){
            f = 5;
        }
        if (file == bytes1("g")){
            f = 6;
        }
        if (file == bytes1("h")){
            f = 7;
        }
    }

    function coordsToSq(bytes memory coords) internal returns (uint sq){
        sq = parseRankStr(coords[1]) * 8 + parseFileStr(coords[0]);
        return sq;
    }

    // TODO (1) handle castles and pawn promotino (= sign)
    function parsePGNMove(
        bytes memory move, 
        uint side, 
        uint64[12] memory bitboards, 
        uint16 moveCount, 
        uint16 gameId
    ) public returns (uint moveValue){
        // pawn move
        uint lIndex = move.length - 1;
        if (move[lIndex] == bytes1("+") || move[lIndex] == bytes1("#")){
            lIndex -= 1;
        }

        uint targetSq = coordsToSq(bytes.concat(move[lIndex-1], move[lIndex]));
        
        Piece sP;
        uint sourceSq;
        if (lIndex-1 != 0){
            lIndex -= 1;

            if (move[lIndex] == bytes1("x") && lIndex == 0){
                // pawn
                sP = side == 0 ? Piece.P : Piece.p;
                sourceSq = findPieceSq(sP, bitboards, targetSq, 8, 8);
            }else {
                if (move[lIndex] == bytes1("x")){
                    lIndex -= 1;
                }

                // 0 or 1
                if (lIndex == 0){
                    // piece
                    sP = parsePiece(move[lIndex], side);
                    sourceSq = findPieceSq(sP, bitboards, targetSq, 8, 8);
                }else {
                    uint f = parseFileStr(move[lIndex]);
                    uint r = parseRankStr(move[lIndex]);
                    sP = parsePiece(move[lIndex-1], side);
                    sourceSq = findPieceSq(sP, bitboards, targetSq, r, f);
                }
            }
        }else{
            // pawn move
            sP = side == 0 ? Piece.P : Piece.p;
            sourceSq = findPieceSq(sP, bitboards, targetSq, 8, 8);

        }

        moveValue = encodeMove(
            sourceSq, 
            targetSq, 
            0,
            false,   
            side,
            gameId,
            moveCount
        );
    }

    function test_parsePGNToMoveValue() public {
        string memory pgnStr = "1. d4 d5 2. Nf3 c5 3. c3 e6 4. e3 Nf6 ";

        uint16 gameId = 1;
        newGame();

        // run
        bytes memory pgnBytes = bytes(pgnStr);
        uint index = 0;
        uint16 moveCount = 0;
        uint moveValue;
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
            moveCount += 1;
            moveValue = parsePGNMove(
                whiteM,
                0,
                gamesState[gameId].bitboards,
                moveCount,
                gameId
            );
            printMove(moveValue);
            applyMove(moveValue);
            printBoard(1);

            index += 1; // skip space

            // collect black move 
            bytes memory blackM;
            while (pgnBytes[index] != bytes1(" ")){
                blackM = bytes.concat(blackM, pgnBytes[index]);
                index += 1;
            }
            emit log_string(string(blackM));
            moveCount += 1;
            moveValue = parsePGNMove(
                blackM,
                1,
                gamesState[gameId].bitboards,
                moveCount,
                gameId
            );
            printMove(moveValue);
            applyMove(moveValue);
            printBoard(1);

            index += 1;
        }
        assertTrue(false);

    }

    function printBoard(uint16 gameId) public {
        GameState memory gameState = gamesState[gameId];

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

    function tst_printBoard() public {
        newGame();

        // apply move
        uint moveValue = encodeMove(
            50,
            42,
            0,
            false,
            0,
            1,
            1
        );

        uint sourceSq = uint64(moveValue & 63);
        uint64 b = uint64(1 << sourceSq);
        uint16 gameId = uint16(moveValue >> 20);
        emit log_named_uint("moveValue ", moveValue);
        emit log_named_uint("gameId ", gameId);
        emit log_named_uint("source sq ", sourceSq);
        emit log_named_uint("b ", b);
        emit log_named_uint("gameId ", decodeGameIdFromMoveValue(moveValue));
        emit log_named_uint("moveCount ", decodeMoveCountFromMoveValue(moveValue));

        uint64[12] memory bitboards = gamesState[1].bitboards;
        for (uint64 index = 0; index < bitboards.length; index++) {
            uint64 board = bitboards[index];
            emit log_named_uint("board ", board);
            if ((b & board)>0){
                emit log_named_uint("piece ", index);
            }
        }

        decodeMoveMetadataFromMoveValue(moveValue, bitboards);
        printMove(moveValue);

        //  uint _moveValue2 = encodeMove(
        //     8,
        //     24,
        //     0,
        //     false,
        //     1,
        //     1,
        //     2
        // );

        // uint _moveValue3 = encodeMove(
        //     60,
        //     62,
        //     0,
        //     false,
        //     0,
        //     1,
        //     3
        // );

        // printMove(_moveValue);
        // printMove(_moveValue2);
        // printMove(_moveValue3);
        // applyMove(_moveValue);
        // applyMove(_moveValue2);
        // applyMove(_moveValue3);

       

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