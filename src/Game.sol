// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
// import "ds-test/test.sol";
import "./interfaces/IChess.sol";

contract Game is IChess {
    // gameId => game's state
    mapping(uint16 => GameState) public gamesState;
    
    // game index
    uint16 public gameIndex;

    function getBishopAttacks(uint square, uint blockboard) internal pure returns (uint64 attacks){
        uint sr = square / 8;
        uint sf = square % 8;

        uint r = sr + 1;
        uint f = sf + 1;

        while (r <= 7 && f <= 7){
            uint sq = r * 8 + f;
            uint64 sqPosB = uint64(1 << sq);
            if (sqPosB & blockboard != 0) break;
            attacks |= sqPosB;
            r += 1;
            f += 1;
        }

        if (f != 0){
            r = sr + 1;
            f = sf - 1;
            while (r <= 7){
                uint sq = r * 8 + f;
                uint64 sqPosB = uint64(1 << sq);
                if (sqPosB & blockboard != 0) break;
                attacks |= sqPosB;
                r += 1;
                if (f == 0) break;
                f -= 1;
            }
        }

        if (r != 0){
            r = sr - 1;
            f = sf + 1;
            while (f <= 7){
                uint sq = r * 8 + f;
                uint64 sqPosB = uint64(1 << sq);
                if (sqPosB & blockboard != 0) break;
                attacks |= sqPosB;
                f += 1;
                if (r == 0) break;
                r -= 1;
            }
        }

        if (r != 0 && f != 0){
            r = sr - 1;
            f = sf - 1;
            while (true){
                uint sq = r * 8 + f;
                uint64 sqPosB = uint64(1 << sq);
                if (sqPosB & blockboard != 0) break;
                attacks |= sqPosB;
                if (r == 0 || f == 0) break;
                r -= 1;
                f -= 1;
            }
        }
    }

    function getRookAttacks(uint square, uint blockboard) internal pure returns (uint64 attacks) {
        uint sr = square / 8;
        uint sf = square % 8;

        uint r = sr + 1;
        uint f;

        while (r <= 7){
            uint sq = r * 8 + sf;
            uint64 sqPosB = uint64(1 << sq);
            if (sqPosB & blockboard != 0) break;
            attacks |= sqPosB;
            r += 1;
        }

        f = sf + 1;
        while (f <= 7){
            uint sq = sr * 8 + f;
            uint64 sqPosB = uint64(1 << sq);
            if (sqPosB & blockboard != 0) break;
            attacks |= sqPosB;
            f += 1;
        }

        if (sr != 0){
            r = sr - 1;
            while (true){
                uint sq = r * 8 + sf;
                uint64 sqPosB = uint64(1 << sq);
                if (sqPosB & blockboard != 0) break;
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
                if (sqPosB & blockboard != 0) break;
                attacks |= sqPosB;
                if (f == 0) break;
                f -= 1;
            }
        }
    }

    function getPawnAttacks(uint square, uint side) internal pure returns (uint64 attacks){
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

    function getKingAttacks(uint square) internal pure returns (uint64 attacks){
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

    function getKnightAttacks(uint square) internal pure returns (uint64 attacks){
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

    function isSquareAttacked(uint square, Piece piece, uint64[12] memory bitboards, uint blockboard) internal pure returns (bool){
        if (piece == Piece.uk){
            return false;
        }

        uint side;
        if (uint(piece) < 6){
            side = 1;
        }

        // check black pawn attacks on sq
        if (side == 0 && getPawnAttacks(square, side) & bitboards[uint(Piece.p)] != 0) {
            return true;
        }

        // check white pawn attacks on sq
        if (side == 1 && getPawnAttacks(square, side) & bitboards[uint(Piece.P)] != 0) {
            return true;
        }

        // check kings attacks on sq
        if (getKingAttacks(square) & (side == 0 ? bitboards[uint(Piece.k)] : bitboards[uint(Piece.K)]) != 0) {
            return true;
        }

        // check knight attacks on sq
        if (getKnightAttacks(square) & (side == 0 ? bitboards[uint(Piece.n)] : bitboards[uint(Piece.N)]) != 0){
            return true;
        }

        // bishop attacks on sq
        uint64 bishopAttacks = getBishopAttacks(square, blockboard);
        if (bishopAttacks & (side == 0 ? bitboards[uint(Piece.b)] : bitboards[uint(Piece.B)]) != 0){
            return true;
        }

        // rook attacks on sq
        uint64 rookAttacks = getRookAttacks(square, blockboard);
        if (rookAttacks & (side == 0 ? bitboards[uint(Piece.r)] : bitboards[uint(Piece.R)]) != 0){
            return true;
        }

        // queen attacks on sq
        uint64 queenAttacks = bishopAttacks | rookAttacks;
        if (queenAttacks & (side == 0 ? bitboards[uint(Piece.q)] : bitboards[uint(Piece.Q)]) != 0){
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

    function decodeMoveMetadataFromMoveValue(uint256 moveValue, uint64[12] memory bitboards) internal pure returns (MoveMetadata memory moveMetadata) {
        moveMetadata.sourceSq = uint64(moveValue & 63);
        moveMetadata.targetSq = uint64((moveValue >> 6) & 63);
        moveMetadata.side = (moveValue >> 17) & 1;
        moveMetadata.moveCount = uint16(moveValue >> 36);

        // flags
        uint pawnPromotion = (moveValue >> 12) & 15;
        uint castleFlag = (moveValue >> 16) & 1;

        // set flags
        require(pawnPromotion > 0 && pawnPromotion < 12 && castleFlag == 0 || pawnPromotion == 0, "Invalid flags");
        moveMetadata.moveFlag = MoveFlag.NoFlag;
        moveMetadata.promotedToPiece = Piece.uk;
        if (pawnPromotion != 0){
            moveMetadata.moveFlag = MoveFlag.PawnPromotion;
            moveMetadata.promotedToPiece = Piece(pawnPromotion);
        }
        if (castleFlag == 1){
           moveMetadata.moveFlag = MoveFlag.Castle;
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
        moveMetadata.sourcePiece = Piece.uk;
        moveMetadata.targetPiece = Piece.uk;
        moveMetadata.sourcePieceBitBoard = uint64(1) << moveMetadata.sourceSq;
        moveMetadata.targetPieceBitBoard = uint64(1) << moveMetadata.targetSq;
        for (uint64 index = 0; index < bitboards.length; index++) {
            uint64 board = bitboards[index];
            if ((moveMetadata.sourcePieceBitBoard & board)>0){
                moveMetadata.sourcePiece = Piece(index);
            }
            if ((moveMetadata.targetPieceBitBoard & board)>0){
                moveMetadata.targetPiece = Piece(index);
            }
        }
        require(moveMetadata.sourcePiece != Piece.uk, "Unknown Piece");
    }

    function getBlockerboard(uint64[12] memory bitboards) internal pure returns (uint64 blockerboard){
        blockerboard |= bitboards[uint(Piece.p)];
        blockerboard |= bitboards[uint(Piece.n)];
        blockerboard |= bitboards[uint(Piece.b)];
        blockerboard |= bitboards[uint(Piece.r)];
        blockerboard |= bitboards[uint(Piece.q)];
        blockerboard |= bitboards[uint(Piece.k)];

        blockerboard |= bitboards[uint(Piece.P)];
        blockerboard |= bitboards[uint(Piece.N)];
        blockerboard |= bitboards[uint(Piece.B)];
        blockerboard |= bitboards[uint(Piece.R)];
        blockerboard |= bitboards[uint(Piece.Q)];
        blockerboard |= bitboards[uint(Piece.K)];
    }

    function isMoveValid(GameState memory gameState, MoveMetadata memory move) public pure returns (bool) {    
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
        if (gameState.side == 0 && move.targetPiece != Piece.uk && uint(move.targetPiece) >= 6){
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

        if (move.moveFlag == MoveFlag.Castle){
            if (move.sourcePiece != Piece.K && move.sourcePiece != Piece.k){
                return false;
            }

            // white king
            if (move.sourcePiece == Piece.K){
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
                    if (1 << 63 & gameState.bitboards[uint(Piece.R)] == 0){
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
                    if (1 << 56 & gameState.bitboards[uint(Piece.R)] == 0){
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
            if (move.sourcePiece == Piece.k){
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
                    if (1 << 7 & gameState.bitboards[uint(Piece.r)] == 0){
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
                    if (1 & gameState.bitboards[uint(Piece.r)] == 0){
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
        if ((move.sourcePiece == Piece.K || move.sourcePiece == Piece.k) && move.moveFlag == MoveFlag.NoFlag){
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
        if ((move.sourcePiece == Piece.N || move.sourcePiece == Piece.n) && move.moveFlag == MoveFlag.NoFlag) {
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
        if ((move.sourcePiece == Piece.P || move.sourcePiece == Piece.p) && (move.moveFlag == MoveFlag.NoFlag || move.moveFlag == MoveFlag.PawnPromotion)){
            // white pawns can only move upwards & black pawns can only move downwards
            if (
                (move.sourcePiece != Piece.P || move.moveLeftShift != false) &&
                (move.sourcePiece != Piece.p || move.moveLeftShift != true)
            ){
                return false;
            }

            // diagonal move (i.e.) attack
            if (move.moveBySq == 9 || move.moveBySq == 7){
                // can only move diagonal if target piece present || it is a enpassant sq
                if (move.targetPiece == Piece.uk && move.targetSq != gameState.enpassantSq){
                    return false;
                }

                // white pawns
                if (move.sourcePiece == Piece.P){
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
                else if(move.sourcePiece == Piece.p){
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
                if (move.targetPiece != Piece.uk){
                    return false;
                }

                // cannot go out of the board;
                // up
                if (move.sourcePieceBitBoard >> move.moveBySq == 0){
                    return false;
                }
                // down
                if (move.sourcePieceBitBoard << move.moveBySq == 0){
                    return false;
                }
            }else if (move.moveBySq == 16) {
                // target sq should be empty 
                if (move.targetPiece != Piece.uk){
                    return false;
                }

                // pawn shouldn't have moved before
                // 71776119061217280 is initial pos of white pawns on board
                // 65280 is initial pos of black pawns on board
                if ((move.sourcePiece != Piece.P || move.sourcePieceBitBoard & 71776119061217280 == 0) && 
                    (move.sourcePiece != Piece.p || move.sourcePieceBitBoard & 65280 == 0) 
                ){
                    return false;
                }
            }
            else {
                return false;
            }

            // check for promotion
            if (move.moveFlag == MoveFlag.PawnPromotion){
                // promoted piece cannot be unkown, cannot be a pawn
                if (move.promotedToPiece == Piece.uk || uint(move.promotedToPiece) == 0 || uint(move.promotedToPiece) == 6){
                    return false;
                }

                // white cannot promote black pice & vice versa
                if ((move.sourcePiece != Piece.P || uint(move.promotedToPiece) < 6) && (move.sourcePiece != Piece.p || uint(move.promotedToPiece) >= 6)){
                    return false;
                }

                // current rank should be 1 or 6
                uint rank = move.sourceSq / 8;
                if ((move.sourcePiece != Piece.P || rank != 1) && (move.sourcePiece != Piece.p || rank != 6)){
                    return false;
                }
            }
        }   

        // bishop & possibly queen
        if (
            (
                (move.sourcePiece == Piece.B || move.sourcePiece == Piece.b) || 
                (
                    // queen moves like a bishop if both rank and file of source & target don't match
                    (move.sourcePiece == Piece.Q || move.sourcePiece == Piece.q) 
                    && (move.sourceSq % 8 != move.targetSq % 8)
                    && (move.sourceSq / 8 != move.targetSq / 8)
                )
            )
            && move.moveFlag == MoveFlag.NoFlag
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
                (move.sourcePiece == Piece.R || move.sourcePiece == Piece.r) || 
                (
                    // queen moves like a rook if both either of rank and file of source & target match
                    (move.sourcePiece == Piece.Q || move.sourcePiece == Piece.q) 
                    && ((move.sourceSq % 8 == move.targetSq % 8)
                        || (move.sourceSq / 8 == move.targetSq / 8))
                )
            )
            && move.moveFlag == MoveFlag.NoFlag
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

    function applyMove(uint256 _moveValue) internal {
        uint16 _gameId = decodeGameIdFromMoveValue(_moveValue);
        GameState memory gameState = gamesState[_gameId];
        MoveMetadata memory move = decodeMoveMetadataFromMoveValue(_moveValue, gameState.bitboards);
        
        // check whether move is valid
        require(isMoveValid(gameState, move), "Invalid move");

        // check game over
        if (move.targetPiece == Piece.K){
            // black won
            gameState.winner = 1;
            gameState.state = 2;
        }else if (move.targetPiece == Piece.k){
            // white won
            gameState.winner = 0;
            gameState.state = 2;
        }
        // game not over
        else {
            // update source piece pos to target sq
            gameState.bitboards[uint(move.sourcePiece)] = (gameState.bitboards[uint(move.sourcePiece)] | uint64(1) << move.targetSq) & ~(uint64(1) << move.sourceSq);

            // remove target piece from target sq
            if (move.targetPiece != Piece.uk ){
                gameState.bitboards[uint(move.targetPiece)] &= ~uint64(1) << move.targetSq;
            }

            // update pawn promotion
            if (move.moveFlag == MoveFlag.PawnPromotion){
                // add promoted piece at target sq
                gameState.bitboards[uint(move.promotedToPiece)] |= uint64(1) << move.targetSq;
                // remove pawn from target sq
                gameState.bitboards[uint(move.sourcePiece)] &= ~uint64(1) << move.targetSq;
            }
            
            // update enpassant
            if (move.moveFlag == MoveFlag.DoublePush){
                gameState.enpassantSq = move.moveLeftShift == true ? move.sourceSq + 8 : move.sourceSq - 8;
            }else {
                gameState.enpassantSq = 0; // Note 0 is an illegal enpassant square
            }

            // update castling rights
            if (move.sourcePiece == Piece.K){
                gameState.wkC = false;
                gameState.wqC = false;
            }
            if (move.sourcePiece == Piece.R){
                if (move.sourceSq == 56){
                    gameState.wqC = false;
                }else if (move.sourceSq == 63){
                    gameState.wkC = false;
                }
            }
            if (move.sourcePiece == Piece.k){
                gameState.bkC = false;
                gameState.bqC = false;
            }
            if (move.sourcePiece == Piece.r){
                if (move.sourceSq == 0){
                    gameState.bqC = false;
                }else if (move.sourceSq == 7){
                    gameState.bkC = false;
                }
            }

            // switch playing side
            if (gameState.side == 0){
                gameState.side = 1;
            }else{
                gameState.side = 0;
            }

            // increase move count
            gameState.moveCount += 1;
        }

        // update game's state
        gamesState[_gameId] = gameState;
    }

    function newGame() public {
        uint16 _gameIndex = gameIndex;

        // initialise game state
        GameState memory _gameState;
        _gameState.state = 1;
        _gameState.winner = 2;
        _gameState.bkC = true;
        _gameState.bqC = true;
        _gameState.wkC = true;
        _gameState.wqC = true;

        
        // initial bitbaords
        _gameState.bitboards = [
            // initial black pos
            65280,
            66,
            36,
            129,
            8,
            16,
            // initial white pos
            71776119061217280,
            4755801206503243776,
            2594073385365405696,
            9295429630892703744,
            576460752303423488,
            1152921504606846976
        ];

        // add game
        gamesState[_gameIndex + 1] = _gameState;

        // update index
        gameIndex = _gameIndex + 1;
    }


}

































































































/**
    Move bits
   0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0011 1111 source sq
   0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 1111 1100 0000 target sq
   0000 0000 0000 0000 0000 0000 0000 0000 0000 1111 0000 0000 0000 promoted piece
   0000 0000 0000 0000 0000 0000 0000 0000 0001 0000 0000 0000 0000 castle flag
   0000 0000 0000 0000 0000 0000 0000 0000 0010 0000 0000 0000 0000 side
   0000 0000 0000 0000 1111 1111 1111 1111 0000 0000 0000 0000 0000 game id
   1111 1111 1111 1111 0000 0000 0000 0000 0000 0000 0000 0000 0000 move count
                             gameid    // 
                             moveCount // 16 
    52 bits. 
    uint56 since 52 isn't present; probably can use extra bits to crunch in somme extra info
 */

/**

    Block pieces 

    p ()
    0 0 0 0 0 0 0 0 
    1 1 1 1 1 1 1 1 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 

    n
    0 1 0 0 0 0 1 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0

    r
    1 0 0 0 0 0 0 1
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 

    q
    0 0 0 1 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0

    k
    0 0 0 0 1 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 

    White pieces 
    
    P
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    1 1 1 1 1 1 1 1 
    0 0 0 0 0 0 0 0 

    N
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 1 0 0 0 0 1 0

    R
    0 0 0 0 0 0 0 0
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    1 0 0 0 0 0 0 1

    Q
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 1 0 0 0 0

    K
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 1 0 0 0 


 */
    