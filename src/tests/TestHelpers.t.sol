// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./../Game.sol";
import "./../libraries/String.sol";
import "./../libraries/Uint.sol";
import "./../interfaces/IGocDataTypes.sol";
import "ds-test/test.sol";

contract TestHelpers is Game, DSTest {
    using String for string;
    using Uint for uint;

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

    function parsePiece(bytes1 piece, uint side) public returns (Piece p) {
        p = Piece.uk;

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

    function coordsToSq(bytes memory coords) internal returns (uint sq){
        sq = parseRankStr(coords[1]) * 8 + parseFileStr(coords[0]);
        return sq;
    }

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

    function isEqual(bytes memory b1, bytes memory b2) public returns (bool){
        return keccak256(abi.encodePacked(b1)) == keccak256(abi.encodePacked(b2));
    }

    function findSourceSqForTargetSq(Piece p, uint side, uint64[12] memory bitboards, uint targetSq, uint eR, uint eF) public returns (uint sq){
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
        }
        if (p == Piece.Q || p == Piece.q){
            attackBoard = getRookAttacks(side == 0 ? Piece.Q : Piece.q, targetSq, blockboard, bitboards);
            attackBoard |= getBishopAttacks(side == 0 ? Piece.Q : Piece.q, targetSq, blockboard, bitboards);
        }
        for (uint256 index = 0; index < 64; index++) {      
            uint64 newBoard = uint64(1 << index);
            if (sourceBoard & newBoard != 0){
                if (attackBoard & newBoard != 0){
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

    // TODO (1) pawn promotion (= sign)
    function parsePGNToMoveValue(
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
                    sourceSq = findSourceSqForTargetSq(sP, side, bitboards, targetSq, 8, 8);
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
                        sourceSq = findSourceSqForTargetSq(sP, side, bitboards, targetSq, 8, 8);
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
                        sourceSq = findSourceSqForTargetSq(sP, side, bitboards, targetSq, r, f);
                    }
                }
            }else{
                // pawn move
                sP = side == 0 ? Piece.P : Piece.p;
                sourceSq = findSourceSqForTargetSq(sP, side, bitboards, targetSq, 8, 8);

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

            // emit log_named_uint("Source sq: ", sourceSq);
            // emit log_named_uint("Target sq: ", targetSq);
            // emit log_named_uint("Game Id: ", gameId);
            // emit log_named_uint("Move Count: ", moveCount);
            // emit log_named_uint("Move Value: ", moveValue);
        }
    }


    ///////////////////////////////// PRINT HELPERS /////////////////////////////////
    
    function formatBoardToString(uint16 _gameId) internal returns (string memory p) {
        uint64[12] memory bitboards = gamesState[_gameId].bitboards;
        uint[] memory boardMap = new uint[](64);

        // make every index 64 for for overlapping indentification
        for (uint256 index = 0; index < 64; index++) {
            boardMap[index] = 12;
        }
       
        for (uint256 pIndex = 0; pIndex < 12; pIndex++) {
            uint64 board = bitboards[pIndex];
            for (uint256 index = 0; index < 64; index++) {
                if (board & (1 << index) != 0){
                    require(boardMap[index] == 12, "PRINT: Invalid board");
                    boardMap[index] = pIndex;
                }
            }
        }

        for (uint256 index = 0; index < 64; index++) {
            uint piece = boardMap[index];

            if (index%8 == 0){
                p = p.append("\n");
            }

            if (piece == 0){
                p = p.append(unicode" ♙");
            } 
            if (piece == 1){
                p = p.append(unicode" ♘");
            }    
            if (piece == 2){
                p = p.append(unicode" ♗");
            }
            if (piece == 3){
                p = p.append(unicode" ♖");
            }
            if (piece == 4){
                p = p.append(unicode" ♕");
            }
            if (piece == 5){
                p = p.append(unicode" ♔");
            }
            if (piece == 6){
                p = p.append(unicode" ♟︎");
            }
            if (piece == 7){
                p = p.append(unicode" ♞");
            }
            if (piece == 8){
                p = p.append(unicode" ♝");
            }
            if (piece == 9){
                p = p.append(unicode" ♜");
            }
            if (piece == 10){
                p = p.append(unicode" ♛");
            }
            if (piece == 11){
                p = p.append(unicode" ♚");
            }
            if (piece == 12){
                p = p.append(unicode" .");
            }
        }
        p = p.append("\n");

    }

    function formatMoveMetadataToString(uint _moveValue) internal returns (string memory p) {
        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        GameState memory _gameState = gamesState[_gameId];
        MoveMetadata memory moveMetadata = decodeMoveMetadataFromMoveValue(_moveValue, _gameState.bitboards);

        p = p.append(string("\n Game ID: ").append(uint(_gameId).toString()));
        if (moveMetadata.side == 0){
            p = p.append("\n Side: WHITE");
        }else{
            p = p.append("\n Side: BLACK");
        }
        p = p.append(string("\n Move Count: ").append(uint(moveMetadata.moveCount).toString()));
        p = p.append(string("\n Target Sq : )").append(uint(moveMetadata.targetSq).toString()));
        p = p.append(string("\n Move By Sq : ").append(uint(moveMetadata.moveBySq).toString()));
        p = p.append(string("\n Source Piece : ").append(uint(moveMetadata.sourcePiece).toString()));
        if (uint(moveMetadata.moveFlag) == 0){
            p = p.append("\n Flag: No Flag");
        }
        if (uint(moveMetadata.moveFlag) == 1){
            p = p.append("\n Flag: Castle");
        }
        if (uint(moveMetadata.moveFlag) == 2){
            p = p.append("\n Flag: Pawn Promotion");
        }
        p = p.append("\n");
        // emit log_string(p);
    }
}