// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./../interfaces/IGocDataTypes.sol";
import "./../libraries/String.sol";
import "./../libraries/Uint.sol";

library GameHelpers {
    using String for string;
    using Uint for uint;

    function parseBitboardsToString(uint64[12] memory bitboards) internal pure returns (string memory) {
        uint[] memory boardMap = new uint[](64);

        // make every index 12 for overlapping indentification
        for (uint256 index = 0; index < 64; index++) {
            boardMap[index] = 12;
        }

        for (uint256 pIndex = 0; pIndex < 12; pIndex++) {
            uint64 board = bitboards[pIndex];
            for (uint256 index = 0; index < 64; index++) {
                if (board & (1 << index) != 0){
                    require(boardMap[index] == 12, "Invalid board");
                    boardMap[index] = pIndex;
                }
            }
        }

        string memory boardString;
        // convert board map string
        for (uint256 index = 0; index < 64; index++) {
            if (index % 8 == 0 && index != 0){
                boardString = boardString.append(string(" | "));
            }

            boardString = boardString.append(string(" "));
            boardString = boardString.append(boardMap[index].toString());
            boardString = boardString.append(string(" "));
        }

        return boardString;
    }

    function getBishopAttacks(IGocDataTypes.Piece attackingPiece, uint square, uint blockboard, uint64[12] memory bitboards) internal pure returns (uint64 attacks){
        uint sr = square / 8;
        uint sf = square % 8;

        uint r = sr + 1;
        uint f = sf + 1;

        // potential attacking sqaures
        uint64 aBishopB = bitboards[uint(attackingPiece)];

        while (r <= 7 && f <= 7){
            uint sq = r * 8 + f;
            uint64 sqPosB = uint64(1 << sq);

            if (sqPosB & aBishopB != 0){
                attacks |= sqPosB;
                break;
            }else if (sqPosB & blockboard != 0) break;

            r += 1;
            f += 1;
        }

        if (sf != 0){
            r = sr + 1;
            f = sf - 1;
            while (r <= 7){
                uint sq = r * 8 + f;
                uint64 sqPosB = uint64(1 << sq);
                
                if (sqPosB & aBishopB != 0){
                    attacks |= sqPosB;
                    break;
                }else if (sqPosB & blockboard != 0) break;

                r += 1;
                if (f == 0) break;
                f -= 1;
            }
        }

        if (sr != 0){
            r = sr - 1;

            f = sf + 1;
            
            while (f <= 7){
                uint sq = r * 8 + f;
                uint64 sqPosB = uint64(1 << sq);
                
                if (sqPosB & aBishopB != 0){
                    attacks |= sqPosB;
                    break;
                }else if (sqPosB & blockboard != 0) break;

                f += 1;
                if (r == 0) break;
                r -= 1;
            }
        }


        if (sr != 0 && sf != 0){
            r = sr - 1;
            f = sf - 1;
            while (true){
                uint sq = r * 8 + f;
                uint64 sqPosB = uint64(1 << sq);
                
                if (sqPosB & aBishopB != 0){
                    attacks |= sqPosB;
                    break;
                }else if (sqPosB & blockboard != 0) break;

                if (r == 0 || f == 0) break;
                r -= 1;
                f -= 1;
            }
        }
    }

    function getRookAttacks(IGocDataTypes.Piece attackingPiece, uint square, uint blockboard, uint64[12] memory bitboards) internal pure returns (uint64 attacks) {
        uint sr = square / 8;
        uint sf = square % 8;

        uint r = sr + 1;
        uint f;

        // potential attacking sqaures
        uint64 aRookB = bitboards[uint(attackingPiece)];

        while (r <= 7){
            uint sq = r * 8 + sf;
            uint64 sqPosB = uint64(1 << sq);

            if (aRookB & sqPosB != 0){
                attacks |= sqPosB;
                break;
            }else if (sqPosB & blockboard != 0) break;
            
            r += 1;
        }

        f = sf + 1;
        while (f <= 7){
            uint sq = sr * 8 + f;
            uint64 sqPosB = uint64(1 << sq);
            
            if (aRookB & sqPosB != 0){
                attacks |= sqPosB;
                break;
            }else if (sqPosB & blockboard != 0) break;

            attacks |= sqPosB;
            f += 1;
        }

        if (sr != 0){
            r = sr - 1;
            while (true){
                uint sq = r * 8 + sf;
                uint64 sqPosB = uint64(1 << sq);

                if (aRookB & sqPosB != 0){
                    attacks |= sqPosB;
                    break;
                }else if (sqPosB & blockboard != 0) break;

                attacks |= sqPosB;
                if (r == 0) break;
                r -= 1;
            }
        }

        if (sf != 0){
            f = sf - 1;
            while (true){
                uint sq = sr * 8 + f;
                uint64 sqPosB = uint64(1 << sq);
                
                if (aRookB & sqPosB != 0){
                    attacks |= sqPosB;
                    break;
                }else if (sqPosB & blockboard != 0) break;

                attacks |= sqPosB;
                if (f == 0) break;
                f -= 1;
            }
        }
    }

    function getPawnAttacks(uint square, uint side) internal  pure returns (uint64 attacks){
        // not files, for move validations
        uint64 notAFile = 18374403900871474942;
        uint64 notHFile = 9187201950435737471;

        uint64 sqBitboard = uint64(1 << square);

        // white pawn
        if (side == 0){
            if (sqBitboard >> 7 & notAFile != 0) attacks |= sqBitboard >> 7;
            if (sqBitboard >> 9 & notHFile != 0) attacks |= sqBitboard >> 9;
        }
        // black pawn
        else {
            if (sqBitboard << 9 & notAFile != 0) attacks |= sqBitboard << 9;
            if (sqBitboard << 7 & notHFile != 0) attacks |= sqBitboard << 7;
        }
    }

    function getKingAttacks(uint square) internal  pure returns (uint64 attacks){
        // not files, for move validations
        uint64 notAFile = 18374403900871474942;
        uint64 notHFile = 9187201950435737471;

        uint64 sqBitboard = uint64(1 << square);

        // upwards
        if (sqBitboard >> 8 != 0) attacks |= sqBitboard >> 8;
        if (sqBitboard >> 9 & notHFile != 0) attacks |= sqBitboard >> 9;
        if (sqBitboard >> 7 & notAFile != 0) attacks |= sqBitboard >> 7;
        if (sqBitboard >> 1 & notHFile != 0) attacks |= sqBitboard >> 1;

        // downwards
        if (sqBitboard << 8 != 0) attacks |= sqBitboard << 8;
        if (sqBitboard << 9 & notAFile != 0) attacks |= sqBitboard << 9;
        if (sqBitboard << 7 & notHFile != 0) attacks |= sqBitboard << 7;
        if (sqBitboard << 1 & notAFile != 0) attacks |= sqBitboard << 1;
    }

    function getKnightAttacks(uint square) internal  pure returns (uint64 attacks){
        // not files, for move validations
        uint64 notAFile = 18374403900871474942;
        uint64 notHFile = 9187201950435737471;
        uint64 notHGFile = 4557430888798830399;
        uint64 notABFile = 18229723555195321596;

        uint64 sqBitboard = uint64(1 << square);

        // upwards
        if (sqBitboard >> 15 & notAFile != 0) attacks |= sqBitboard >> 15;
        if (sqBitboard >> 17 & notHFile != 0) attacks |= sqBitboard >> 17;
        if (sqBitboard >> 6 & notABFile != 0) attacks |= sqBitboard >> 6;
        if (sqBitboard >> 10 & notHGFile != 0) attacks |= sqBitboard >> 10;

        // downwards
        if (sqBitboard << 15 & notHFile != 0) attacks |= sqBitboard << 15;
        if (sqBitboard << 17 & notAFile != 0) attacks |= sqBitboard << 17;
        if (sqBitboard << 6 & notHGFile != 0) attacks |= sqBitboard << 6;
        if (sqBitboard << 10 & notABFile != 0) attacks |= sqBitboard << 10;
    }

    function isSquareAttacked(uint square, IGocDataTypes.Piece piece, uint64[12] memory bitboards, uint blockboard) internal returns (bool){
        if (piece == IGocDataTypes.Piece.uk){
            return false;
        }

        uint side;
        if (uint(piece) < 6){
            side = 1;
        }

        // check black pawn attacks on sq
        if (side == 0 && getPawnAttacks(square, side) & bitboards[uint(IGocDataTypes.Piece.p)] != 0) {
            return true;
        }

        // check white pawn attacks on sq
        if (side == 1 && getPawnAttacks(square, side) & bitboards[uint(IGocDataTypes.Piece.P)] != 0) {
            return true;
        }

        // check kings attacks on sq
        if (getKingAttacks(square) & (side == 0 ? bitboards[uint(IGocDataTypes.Piece.k)] : bitboards[uint(IGocDataTypes.Piece.K)]) != 0) {
            return true;
        }


        // check knight attacks on sq
        if (getKnightAttacks(square) & (side == 0 ? bitboards[uint(IGocDataTypes.Piece.n)] : bitboards[uint(IGocDataTypes.Piece.N)]) != 0){
            return true;
        }


        // bishop attacks on sq
        uint64 bishopAttacks = getBishopAttacks(side == 0 ? IGocDataTypes.Piece.b : IGocDataTypes.Piece.B, square, blockboard, bitboards);
        if (bishopAttacks != 0){
            return true;
        }

        // rook attacks on sq
        uint64 rookAttacks = getRookAttacks(side == 0 ? IGocDataTypes.Piece.r : IGocDataTypes.Piece.R, square, blockboard, bitboards);
        if (rookAttacks & (side == 0 ? bitboards[uint(IGocDataTypes.Piece.r)] : bitboards[uint(IGocDataTypes.Piece.R)]) != 0){
            return true;
        }

        // queen attacks on sq
        uint64 queenAttacks = (
            getBishopAttacks(side == 0 ? IGocDataTypes.Piece.q : IGocDataTypes.Piece.Q, square, blockboard, bitboards) | 
            getRookAttacks(side == 0 ? IGocDataTypes.Piece.q : IGocDataTypes.Piece.Q, square, blockboard, bitboards)
        );
        if (queenAttacks & (side == 0 ? bitboards[uint(IGocDataTypes.Piece.q)] : bitboards[uint(IGocDataTypes.Piece.Q)]) != 0){
            return true;
        }


        return false;
    }

    function decodeGameIdFromMoveValue(uint256 moveValue) internal pure returns (uint16 gameId){
        gameId = uint16((moveValue >> 20) & 65535);
    }

    function decodeMoveCountFromMoveValue(uint256 moveValue) internal pure returns (uint16 gameId){
        gameId = uint16(moveValue >> 36);
    }

    function decodeMoveMetadataFromMoveValue(uint256 moveValue, uint64[12] memory bitboards) internal pure returns (IGocDataTypes.MoveMetadata memory moveMetadata) {
        moveMetadata.sourceSq = moveValue & 63;
        moveMetadata.targetSq = (moveValue >> 6) & 63;
        moveMetadata.side = (moveValue >> 17) & 1;
        moveMetadata.moveCount = uint16(moveValue >> 36);

        // flags
        uint pawnPromotion = (moveValue >> 12) & 15;
        uint castleFlag = (moveValue >> 16) & 1;

        // set flags
        require(pawnPromotion > 0 && pawnPromotion < 12 && castleFlag == 0 || pawnPromotion == 0, "Invalid flags");
        moveMetadata.moveFlag = IGocDataTypes.MoveFlag.NoFlag;
        moveMetadata.promotedToPiece = IGocDataTypes.Piece.uk;
        if (pawnPromotion != 0){
            moveMetadata.moveFlag = IGocDataTypes.MoveFlag.PawnPromotion;
            moveMetadata.promotedToPiece = IGocDataTypes.Piece(pawnPromotion);
        }
        if (castleFlag == 1){
           moveMetadata.moveFlag = IGocDataTypes.MoveFlag.Castle;
        }

        // set squares
        if (moveMetadata.targetSq > moveMetadata.sourceSq){
            moveMetadata.moveBySq = moveMetadata.targetSq - moveMetadata.sourceSq;
            moveMetadata.moveLeftShift = true;
        }else if ( moveMetadata.targetSq < moveMetadata.sourceSq){
            moveMetadata.moveBySq = moveMetadata.sourceSq - moveMetadata.targetSq;
            moveMetadata.moveLeftShift = false;
        }
        require(moveMetadata.targetSq != moveMetadata.sourceSq, "No move");

        // set pieces
        moveMetadata.sourcePiece = IGocDataTypes.Piece.uk;
        moveMetadata.targetPiece = IGocDataTypes.Piece.uk;
        moveMetadata.sourcePieceBitBoard = uint64(1 << moveMetadata.sourceSq);
        moveMetadata.targetPieceBitBoard = uint64(1 << moveMetadata.targetSq);
        for (uint64 index = 0; index < bitboards.length; index++) {
            uint64 board = bitboards[index];
            if ((moveMetadata.sourcePieceBitBoard & board)>0){
                moveMetadata.sourcePiece = IGocDataTypes.Piece(index);
            }
            if ((moveMetadata.targetPieceBitBoard & board)>0){
                moveMetadata.targetPiece = IGocDataTypes.Piece(index);
            }
        }
        require(moveMetadata.sourcePiece != IGocDataTypes.Piece.uk, "Unknown Piece");
    }

    function getBlockerboard(uint64[12] memory bitboards) internal pure returns (uint64 blockerboard){
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.p)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.n)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.b)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.r)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.q)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.k)];

        blockerboard |= bitboards[uint(IGocDataTypes.Piece.P)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.N)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.B)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.R)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.Q)];
        blockerboard |= bitboards[uint(IGocDataTypes.Piece.K)];
    }

    function isMoveValid(IGocDataTypes.GameState memory gameState, IGocDataTypes.MoveMetadata memory move) internal returns (bool) {    
        if (gameState.state != 1){
            return false;
        }

        if (move.side != gameState.side) {
            return false;
        }

        if (gameState.moveCount + 1 != move.moveCount){
            return false;
        }

        // source piece should match playing side
        if (gameState.side == 0 && uint(move.sourcePiece) < 6 ){
            // sourcePiece is black, when side is white
            return false;
        }
        if (gameState.side == 1 && uint(move.sourcePiece) >= 6){
            // sourcePiece is white, when side is black
            return false;
        }

        // target piece cannot be of playiing side
        if (gameState.side == 0 && move.targetPiece != IGocDataTypes.Piece.uk && uint(move.targetPiece) >= 6){
            return false;
        }
        if (gameState.side == 1 && uint(move.targetPiece) < 6){
            return false;
        }

        uint64 blockerboard = getBlockerboard(gameState.bitboards);

        // not files, for move validations
        uint64 notAFile = 18374403900871474942;
        uint64 notHFile = 9187201950435737471;
        uint64 notHGFile = 4557430888798830399;
        uint64 notABFile = 18229723555195321596;

        if (move.moveFlag == IGocDataTypes.MoveFlag.Castle){
            if (move.sourcePiece != IGocDataTypes.Piece.K && move.sourcePiece != IGocDataTypes.Piece.k){
                return false;
            }

            // white king
            if (move.sourcePiece == IGocDataTypes.Piece.K){
                // king should be on original pos
                if (move.sourceSq != 60){
                    return false;
                }

                // targetSq can only be 62 or 58
                if (move.targetSq != 62 && move.targetSq != 58){
                    return false;
                }

                // king side castling
                if (move.targetSq == 62){
                    if (gameState.wkC == false){
                        return false;
                    }

                    // rook should be on original pos
                    if (1 << 63 & gameState.bitboards[uint(IGocDataTypes.Piece.R)] == 0){
                        return false;
                    }

                    // no attacks to king and thru passage
                    if (
                        isSquareAttacked(60, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(61, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(62, move.sourcePiece, gameState.bitboards, blockerboard)
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 61 & blockerboard != 0 ||
                        1 << 62 & blockerboard != 0
                    ){
                        return false;
                    }
                }

                // queen side castling
                if (move.targetSq == 58){
                    if (gameState.wqC == false){
                        return false;
                    }
                    
                    // rook should on original pos
                    if (1 << 56 & gameState.bitboards[uint(IGocDataTypes.Piece.R)] == 0){
                        return false;
                    }

                    // no attacks to king and thru passage
                    if (
                        isSquareAttacked(60, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(59, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(58, move.sourcePiece, gameState.bitboards, blockerboard)
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 57 & blockerboard != 0 ||
                        1 << 58 & blockerboard != 0 ||
                        1 << 59 & blockerboard != 0
                    ){
                        return false;
                    }
                }
                
            }

            // black king
            if (move.sourcePiece == IGocDataTypes.Piece.k){
                // king should on original pos
                if (move.sourceSq != 4){
                    return false;
                }

                // targetSq can only be 2 or 6
                if (move.targetSq != 2 && move.targetSq != 6){
                    return false;
                }

                // king side castling
                if (move.targetSq == 6){
                    if (gameState.bkC == false){
                        return false;
                    }

                    // rook should be on 7
                    if ((1 << 7) & gameState.bitboards[uint(IGocDataTypes.Piece.r)] == 0){
                        return false;
                    }

                    // no attacks on king sq & thru sqaures
                    if (
                        isSquareAttacked(4, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(5, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(6, move.sourcePiece, gameState.bitboards, blockerboard) 
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 5 & blockerboard != 0 ||
                        1 << 6 & blockerboard != 0
                    ){
                        return false;
                    }
                }


                // queen side castling
                if (move.targetSq == 2){
                    if (gameState.bqC == false){
                        return false;
                    }

                    // rook should be on 0 
                    if (1 & gameState.bitboards[uint(IGocDataTypes.Piece.r)] == 0){
                        return false;
                    }

                    // no attacks on king sq & thru squares
                    if (
                        isSquareAttacked(4, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(3, move.sourcePiece, gameState.bitboards, blockerboard) ||
                        isSquareAttacked(2, move.sourcePiece, gameState.bitboards, blockerboard) 
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 3 & blockerboard != 0 ||
                        1 << 2 & blockerboard != 0 ||
                        1 << 1 & blockerboard != 0
                    ){
                        return false;
                    }
                }
            }
        }

        // king
        if ((move.sourcePiece == IGocDataTypes.Piece.K || move.sourcePiece == IGocDataTypes.Piece.k) && move.moveFlag == IGocDataTypes.MoveFlag.NoFlag){
            // moveBy can only be 8, 9, 7, 1
            if (move.moveBySq != 8 && move.moveBySq != 9 && move.moveBySq != 7 && move.moveBySq != 1){
                return false;
            }

            // downwards
            if (move.moveLeftShift == true){
                // can only move inside the board
                if (move.sourcePieceBitBoard << uint64(move.moveBySq) == 0){
                    return false;
                }

                // check falling off right edge
                if (move.moveBySq == 9 && (move.sourcePieceBitBoard << 9 & notAFile) == 0){
                    return false;
                }

                // check falling off left edge
                if (move.moveBySq == 7 && (move.sourcePieceBitBoard << 7 & notHFile) == 0){
                    return false;
                }
            }

            // upwards
            if (move.moveLeftShift == false){
                // can only move inside the board
                if (move.sourcePieceBitBoard >> move.moveBySq == 0){
                    return false;
                }

                // check falling off right edge
                if (move.moveBySq == 7 && (move.sourcePieceBitBoard >> 7 & notAFile) == 0){
                    return false;
                }

                // check falling off left edge 
                if (move.moveBySq == 9 && (move.sourcePieceBitBoard >> 9 & notHFile) == 0){
                    return false;
                }
            }
        }

        // knight
        if ((move.sourcePiece == IGocDataTypes.Piece.N || move.sourcePiece == IGocDataTypes.Piece.n) && move.moveFlag == IGocDataTypes.MoveFlag.NoFlag) {
            if (move.moveBySq != 17 && move.moveBySq != 15 && move.moveBySq != 6 && move.moveBySq != 10) {
                return false;
            }

            // downwards
            if (move.moveLeftShift == true){
                // check falling off right edge
                if (move.moveBySq == 17 && (move.sourcePieceBitBoard << 17 & notAFile) == 0){
                    return false;
                }

                // check falling off right edge (2 lvl deep)
                if (move.moveBySq == 10 && (move.sourcePieceBitBoard << 10 & notABFile) == 0){
                    return false;
                }

                // check falling off left edge
                if (move.moveBySq == 15 && (move.sourcePieceBitBoard << 15 & notHFile) == 0){
                    return false;
                }

                // check falling off left edge (2 lvl deep)
                if (move.moveBySq == 6 && (move.sourcePieceBitBoard << 6 & notHGFile) == 0){
                    return false;
                }
            }

            // upwards
            if (move.moveLeftShift == false){
                // check falling off right edge
                if (move.moveBySq == 15 && (move.sourcePieceBitBoard >> 15 & notAFile) == 0){
                    return false;
                }

                // check falling off right edgen (2 lvl deep)
                if (move.moveBySq == 6 && (move.sourcePieceBitBoard >> 6 & notABFile) == 0){
                    return false;
                }

                // check falling off left edge
                if (move.moveBySq == 17 && (move.sourcePieceBitBoard >> 17 & notHFile) == 0){
                    return false;
                }

                // check falling off left edge (2 lvl deep)
                if (move.moveBySq == 10 && (move.sourcePieceBitBoard >> 10 & notHGFile) == 0){
                    return false;
                }
            }

        }
        
        // white & black pawns
        if ((move.sourcePiece == IGocDataTypes.Piece.P || move.sourcePiece == IGocDataTypes.Piece.p) && (move.moveFlag == IGocDataTypes.MoveFlag.NoFlag || move.moveFlag == IGocDataTypes.MoveFlag.PawnPromotion)){
            // white pawns can only move upwards & black pawns can only move downwards
            if (
                (move.sourcePiece != IGocDataTypes.Piece.P || move.moveLeftShift != false) &&
                (move.sourcePiece != IGocDataTypes.Piece.p || move.moveLeftShift != true)
            ){
                return false;
            }

            // diagonal move (i.e.) attack
            if (move.moveBySq == 9 || move.moveBySq == 7){
                // can only move diagonal if target piece present || it is a enpassant sq
                if (move.targetPiece == IGocDataTypes.Piece.uk && move.targetSq != gameState.enpassantSq){
                    return false;
                }

                // white pawns
                if (move.sourcePiece == IGocDataTypes.Piece.P){
                    // check falling off right edge
                    if (move.moveBySq == 7 && (move.sourcePieceBitBoard >> 7 & notAFile) == 0){
                        return false;
                    }
                    // check falling off left edge
                    if (move.moveBySq == 9 && (move.sourcePieceBitBoard >> 9 & notHFile) == 0){
                        return false;
                    }
                }
                // black pawns
                else if(move.sourcePiece == IGocDataTypes.Piece.p){
                    // check falling off right edge
                    if (move.moveBySq == 9 && (move.sourcePieceBitBoard << 9 & notAFile) == 0){
                        return false;
                    }

                    // check falling off right edge
                    if (move.moveBySq == 7 && (move.sourcePieceBitBoard << 7 & notHFile) == 0){
                        return false;
                    }
                }
            }else if (move.moveBySq == 8){
                // targetSq should be empty
                if (move.targetPiece != IGocDataTypes.Piece.uk){
                    return false;
                }

                // cannot go out of the board;
                // up
                if (move.sourcePieceBitBoard >> move.moveBySq == 0){
                    return false;
                }
                // down
                if (move.sourcePieceBitBoard << uint64(move.moveBySq) == 0){
                    return false;
                }
            }else if (move.moveBySq == 16) {
                // target sq should be empty 
                if (move.targetPiece != IGocDataTypes.Piece.uk){
                    return false;
                }

                // pawn shouldn't have moved before
                // 71776119061217280 is initial pos of white pawns on board
                // 65280 is initial pos of black pawns on board
                if ((move.sourcePiece != IGocDataTypes.Piece.P || move.sourcePieceBitBoard & 71776119061217280 == 0) && 
                    (move.sourcePiece != IGocDataTypes.Piece.p || move.sourcePieceBitBoard & 65280 == 0) 
                ){
                    return false;
                }
            }
            else {
                return false;
            }

            // check for promotion
            if (move.moveFlag == IGocDataTypes.MoveFlag.PawnPromotion){
                // promoted piece cannot be unkown, pawn, or king
                if (
                    move.promotedToPiece == IGocDataTypes.Piece.uk || 
                    move.promotedToPiece == IGocDataTypes.Piece.p || 
                    move.promotedToPiece == IGocDataTypes.Piece.P || 
                    move.promotedToPiece == IGocDataTypes.Piece.k || 
                    move.promotedToPiece == IGocDataTypes.Piece.K  
                ){
                    return false;
                }

                // white cannot promote black pice & vice versa
                if ((move.sourcePiece != IGocDataTypes.Piece.P || uint(move.promotedToPiece) < 6) && (move.sourcePiece != IGocDataTypes.Piece.p || uint(move.promotedToPiece) >= 6)){
                    return false;
                }

                // current rank should be 1 or 6
                uint rank = move.sourceSq / 8;
                if ((move.sourcePiece != IGocDataTypes.Piece.P || rank != 1) && (move.sourcePiece != IGocDataTypes.Piece.p || rank != 6)){
                    return false;
                }
            }
        }   

        // bishop & possibly queen
        if (
            (
                (move.sourcePiece == IGocDataTypes.Piece.B || move.sourcePiece == IGocDataTypes.Piece.b) || 
                (
                    // queen moves like a bishop if both rank and file of source & target don't match
                    (move.sourcePiece == IGocDataTypes.Piece.Q || move.sourcePiece == IGocDataTypes.Piece.q) 
                    && (move.sourceSq % 8 != move.targetSq % 8)
                    && (move.sourceSq / 8 != move.targetSq / 8)
                )
            )
            && move.moveFlag == IGocDataTypes.MoveFlag.NoFlag
            ) 
        {
            uint sr = move.sourceSq / 8; 
            uint sf = move.sourceSq % 8;
            uint tr = move.targetSq / 8; 
            uint tf = move.targetSq % 8;
            
            bool targetFound = false;

            // check target is daigonal & there exist no blockers
            if (sr < tr && sf < tf){
                uint r = sr + 1;
                uint f = sf + 1;
                while (r <= 7 && f <= 7){
                    uint sq = (r * 8) + f;

                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }

                    r += 1;
                    f += 1;
                }
            }
            if (sr < tr && sf > tf) {
                uint r = sr + 1;
                uint f = sf - 1;
                while (r <= 7 && f >= 0){
                    uint sq = (r * 8) + f;

                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }

                    r += 1;
                    if (f == 0){
                        break;
                    }
                    f -= 1;
                }
            }
            if (sr > tr && sf > tf) {
                uint r = sr - 1;
                uint f = sf - 1;
                while (r >= 0 && f >= 0){
                    uint sq = (r * 8) + f;

                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }

                    if (r == 0 || f == 0){
                        break;
                    }
                    r -= 1;
                    f -= 1;
                }
            }
            if (sr > tr && sf < tf){
                uint r = sr - 1;
                uint f = sf + 1;
                while (r >= 0 && f <= 7){
                    uint sq = (r * 8) + f;
                    
                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }

                    if (r == 0){
                        break;
                    }
                    r -= 1;
                    f += 1;
                }
            }

            // if targetSq not found, then targetSq isn't positioned diagonally to bishop's pos
            require(targetFound);
        }

        // rook & possibly queen
        if (
            (
                (move.sourcePiece == IGocDataTypes.Piece.R || move.sourcePiece == IGocDataTypes.Piece.r) || 
                (
                    // queen moves like a rook if both either of rank and file of source & target match
                    (move.sourcePiece == IGocDataTypes.Piece.Q || move.sourcePiece == IGocDataTypes.Piece.q) 
                    && ((move.sourceSq % 8 == move.targetSq % 8)
                        || (move.sourceSq / 8 == move.targetSq / 8))
                )
            )
            && move.moveFlag == IGocDataTypes.MoveFlag.NoFlag
            ) 
        {
            uint sr = move.sourceSq / 8; 
            uint sf = move.sourceSq % 8;
            uint tr = move.targetSq / 8; 
            uint tf = move.targetSq % 8;
            
            bool targetFound = false;

            // target sq should be either in same file or rank & should not contains any blockers
            if (sr == tr && sf < tf){
                uint f = sf + 1;
                while (f <= 7){
                    uint sq = (sr * 8) + f;

                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }

                    f += 1;
                }
            }
            if (sr == tr && sf > tf && sf != 0) {
                uint f = sf - 1;
                while (f >= 0){
                    uint sq = (sr * 8) + f;

                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }

                    if (f == 0){
                        break;
                    }
                    f -= 1;
                }
            }
            if (sr > tr && sf == tf && sr != 0) {
                uint r = sr - 1;
                while (r >= 0){
                    uint sq = (r * 8) + sf;

                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }

                    if (r == 0){
                        break;
                    }
                    r -= 1;
                }
            }
            if (sr < tr && sf == tf){
                uint r = sr + 1;
                while (r <= 7){
                    uint sq = (r * 8) + sf;
                    
                    if (sq == move.targetSq){
                        targetFound = true;
                        break;
                    }

                    // check whether blocker exists
                    if ((uint(1) << sq & blockerboard) > 0){
                        break;
                    }
                    r += 1;
                }
            }


            // if targetSq not found, then targetSq isn't valid
            if (targetFound == false) return false;
        }

        return true;
    }

}