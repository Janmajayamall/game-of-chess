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
            p = append(p, "\n Flag: Castle");
        }
        if (uint(moveMetadata.moveFlag) == 2){
            p = append(p, "\n Flag: Pawn Promotion");
        }
        p = append(p, "\n");
        emit log_string(p);
    }

    event DF(bytes1 f, bool k, bytes d);
    event DF(string key, bytes1 f);

    function parsePiece(bytes1 piece, uint side) public returns (Piece p) {
        p = Piece.uk;
        // emit DF("parsePiece ", piece);
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

    function findPieceSq(Piece p, uint side, uint64[12] memory bitboards, uint targetSq, uint eR, uint eF) public returns (uint sq){
        uint64 sourceBoard = bitboards[uint(p)];
        uint64 targetBoard = uint64(1 << targetSq);
        uint64 blockboard = getBlockerboard(bitboards);

        // finding sqaures from where Piece p can reach target sq
        uint64 attackBoard;
        if (p == Piece.P || p == Piece.p){
            // note - getPawnAttack returns squares that can attack the target square while
            // taking the side into consideration. For example, when looking for attack squares
            // when targetSq is assumbed to have a white piece the search would always contain squares
            // that are above the targetSq since black pawns can only attack downwards. 
            // In our case, we need the squares from which pawn of the side can reach the targetSq, 
            // thus we simply flip the side in search. So if we are searching for sqaures from which white
            // pawns can reach the targetSq, we instead search for sqaures from which white pawns can attack
            // the targetSq.
            // blockboard & targetBoard != 0 is required to check whether the targetSq consists of some piece, 
            // since pawns can move diagonally only when targetSq consists something. 
            if (blockboard & targetBoard != 0){
                attackBoard = getPawnAttacks(targetSq, p == Piece.P ? 1 : 0);
            }
            // pawn attacks do not include straight moves, thus adding them separately
            if (p == Piece.P){
                if (targetBoard << 16 != 0) attackBoard |= targetBoard << 16;
                if (targetBoard << 8 != 0) attackBoard |= targetBoard << 8;
            }else if (p == Piece.p){
                if (targetBoard >> 16 != 0) attackBoard |= targetBoard >> 16;
                if (targetBoard >> 8 != 0) attackBoard |= targetBoard >> 8;
            }
            emit log_named_uint("attack board ", attackBoard);
            emit log_named_uint("source board ", sourceBoard);
        }
        if (p == Piece.K || p == Piece.k){
            attackBoard = getKingAttacks(targetSq);
        }
        if (p == Piece.N || p == Piece.n){
            attackBoard = getKnightAttacks(targetSq);
        }
        if (p == Piece.R || p == Piece.r){
            attackBoard = getRookAttacks(side == 0 ? Piece.R : Piece.r, targetSq, blockboard, bitboards);
        }
        if (p == Piece.B || p == Piece.b){
            // flip the side since we are looking for sqaures that can reach target sq, not attack
            attackBoard = getBishopAttacks(side == 0 ? Piece.B : Piece.b, targetSq, blockboard, bitboards);
            // emit log_named_uint("aBishopB ", bitboards[side == 0 ? uint(Piece.b) : uint(Piece.B)]);
            // emit log_named_uint("attack ", attackBoard);
        }
        if (p == Piece.Q || p == Piece.q){
            attackBoard = getRookAttacks(side == 0 ? Piece.Q : Piece.q, targetSq, blockboard, bitboards);
            attackBoard |= getBishopAttacks(side == 0 ? Piece.Q : Piece.q, targetSq, blockboard, bitboards);
        }
        for (uint256 index = 0; index < 64; index++) {      
            uint64 newBoard = uint64(1 << index);
            if (sourceBoard & newBoard != 0){
                if (attackBoard & newBoard != 0){
                    emit log_named_uint("inside index ", index);
                    emit log_named_uint("inside index ", eF);
                    if (eR != 8 && index / 8 == eR){
                        sq = index;
                    }else if (eF != 8 && index % 8 == eF){
                        sq = index;
                    }else if (eR == 8 && eF == 8){
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

    function isEqual(bytes memory b1, bytes memory b2) public returns (bool){
        return keccak256(abi.encodePacked(b1)) == keccak256(abi.encodePacked(b2));
    }

    // TODO (1) pawn promotion (= sign)
    function parsePGNMove(
        bytes memory move, 
        uint side, 
        uint64[12] memory bitboards, 
        uint16 moveCount, 
        uint16 gameId
    ) public returns (uint moveValue){

        // king side castle
        if (isEqual(move, bytes("O-O"))){
            moveValue = encodeMove(
                side == 0 ? 60: 4, 
                side == 0 ? 62: 6, 
                0,
                true,   
                side,
                gameId,
                moveCount
            );
        }
        // queen side castle
        else if (isEqual(move, bytes("O-O-O"))){
            moveValue = encodeMove(
                side == 0 ? 60: 4, 
                side == 0 ? 58: 2, 
                0,
                true,   
                side,
                gameId,
                moveCount
            );
        }
        else {
            uint lIndex = move.length - 1;
            if (move[lIndex] == bytes1("+") || move[lIndex] == bytes1("#")){
                lIndex -= 1;
            }

            uint targetSq = coordsToSq(bytes.concat(move[lIndex-1], move[lIndex]));
            
            Piece sP;
            uint sourceSq;
            if (lIndex-1 != 0){
                lIndex -= 2;

                if (move[lIndex] == bytes1("x") && lIndex == 0){
                    // pawn
                    sP = side == 0 ? Piece.P : Piece.p;
                    sourceSq = findPieceSq(sP, side, bitboards, targetSq, 8, 8);
                }else {
                    if (move[lIndex] == bytes1("x")){
                        lIndex -= 1;
                    }

                    // lIndex is either 0 or 1
                    // note - If lIndex == 0, it means that the char at index is either a piece,
                    // or rank/column defining position of pawn piece (for situations when 2 pawns can perform
                    // the same move).
                    // If lIndex == 1, then index pos 1 defines rank/column of piece at index pos 0
                    if (lIndex == 0 && parsePiece(move[lIndex], side) != Piece.uk){
                        // it's a piece
                        sP = parsePiece(move[lIndex], side);
                        sourceSq = findPieceSq(sP, side, bitboards, targetSq, 8, 8);
                        
                        // emit Log(move[lIndex], sourceSq);
                    }else {
                        // index at lIndex defines rank/column
                        uint f = parseFileStr(move[lIndex]);
                        uint r = parseRankStr(move[lIndex]);

                        if (lIndex == 0){
                            // pawn piece
                            sP = side == 0 ? Piece.P : Piece.p;
                        }else {
                            sP = parsePiece(move[lIndex-1], side);
                        }
                        sourceSq = findPieceSq(sP, side, bitboards, targetSq, r, f);
                        emit Log(move[lIndex], sourceSq);
                        emit Log(move[lIndex], f);
                        emit Log(move[lIndex], r);
                    }
                }
            }else{
                // pawn move
                sP = side == 0 ? Piece.P : Piece.p;
                sourceSq = findPieceSq(sP, side, bitboards, targetSq, 8, 8);

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
    }
    event Log(bytes1 d, uint s);
    function test_parsePGNToMoveValue() public {
        string memory pgnStr = "1. d4 d5 2. Nf3 c5 3. c4 e6 4. e3 Nf6 5. Bd3 Nc6 6. O-O Bd6 7. b3 O-O 8. Bb2 b6 9. Nbd2 Bb7 10. Rc1 Qe7 11. cxd5 exd5 12. Nh4 g6 13. Nhf3 Rad8 14. dxc5 bxc5 15. Bb5 Ne4 16. Bxc6 Bxc6 17. Qc2 Nxd2 18. Nxd2 d4 19. exd4 Bxh2+ 20. Kxh2 Qh4+ 21. Kg1 Bxg2 22. f3 Rfe8 23. Ne4 Qh1+ 24. Kf2 Bxf1 25. d5 f5 26. Qc3 Qg2+ 27. Ke3 Rxe4+ 28. fxe4 f4+ 29. Kxf4 Rf8+ 30. Ke5 Qh2+ 31. Ke6 Re8+ 32. Kd7 Bb5 ";

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
            // applyMove(moveValue);
            // printBoard(1);

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
            // emit log_string("move applied");
            // applyMove(moveValue);
            // printBoard(1);
            
            

            index += 1;
        }

        assertTrue(true);

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

  /**
    1. try parsing different boards
    2. rearrange the code
   */