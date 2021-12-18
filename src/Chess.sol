// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "ds-test/test.sol";

contract Chess is DSTest {

    // 12 pieces
    enum Piece { 
        p, n, b, r, q, k, P, N, B, R, Q, K, uk
    }

    struct Move {
        uint64 sourceSq;
        uint64 targetSq; 
        uint64 moveBySq; 

        uint64 sourcePieceBitBoard;
        uint64 targetPieceBitBoard;

        bool moveLeftShift; // left shift is down the board & right shift is up the board

        Piece sourcePiece;
        Piece targetPiece;
        Piece promotedToPiece;

        MoveFlag moveFlag;
    }

    enum MoveFlag {
        NoFlag,
        DoublePush,
        Enpassant,
        Castle,
        PawnPromotion
    }

    struct EncodedBitboards {
        uint256 firstPieceB; // p, n, b, r 
        uint256 secondPieceB; // q, k, Q, K
        uint256 thirdPieceB; // P, N, B, R
    }

    struct GameState {
        // playing side
        uint8 side; // 0 -> white, 1 -> black

        // winner
        uint8 winner; // 0 -> white, 1 -> black, 2 -> draw

        // enpassant
        uint64 enpassantSq;

        // castling rights
        bool bkC;
        bool bqC;
        bool wkC;
        bool wqC;
    }

 


    // attacking squares of non-sliding pieces
    mapping(uint => uint64) whitePawnAttacks;
    mapping(uint => uint64) blackPawnAttacks;
    mapping(uint => uint64) kingAttacks;
    mapping(uint => uint64) knightAttacks;

    function decodeBitboards(EncodedBitboards memory eBitboards) internal pure returns (uint64[12] memory bitboards){
        // handling first piece
        bitboards[uint(Piece.r)] = uint64(eBitboards.firstPieceB);
        bitboards[uint(Piece.b)] = uint64(eBitboards.firstPieceB >> 64);
        bitboards[uint(Piece.n)] = uint64(eBitboards.firstPieceB >> 128);
        bitboards[uint(Piece.p)] = uint64(eBitboards.firstPieceB >> 192);

        // handling second piece
        bitboards[uint(Piece.K)] = uint64(eBitboards.secondPieceB);
        bitboards[uint(Piece.Q)] = uint64(eBitboards.secondPieceB >> 64);
        bitboards[uint(Piece.k)] = uint64(eBitboards.secondPieceB >> 128);
        bitboards[uint(Piece.q)] = uint64(eBitboards.secondPieceB >> 192);

        // handling third piece
        bitboards[uint(Piece.R)] = uint64(eBitboards.thirdPieceB);
        bitboards[uint(Piece.B)] = uint64(eBitboards.thirdPieceB >> 64);
        bitboards[uint(Piece.N)] = uint64(eBitboards.thirdPieceB >> 128);
        bitboards[uint(Piece.P)] = uint64(eBitboards.thirdPieceB >> 192);
    }

    function encodeBitboards(uint64[12] memory bitboards) internal pure returns (EncodedBitboards memory eBitboards){
        // handling first piece
        eBitboards.firstPieceB |= uint256(bitboards[uint(Piece.p)]) << 192;
        eBitboards.firstPieceB |= uint256(bitboards[uint(Piece.n)]) << 128;
        eBitboards.firstPieceB |= uint256(bitboards[uint(Piece.b)]) << 64;
        eBitboards.firstPieceB |= uint256(bitboards[uint(Piece.r)]);

        // handling second piece
        eBitboards.secondPieceB |= uint256(bitboards[uint(Piece.q)]) << 192;
        eBitboards.secondPieceB |= uint256(bitboards[uint(Piece.k)]) << 128;
        eBitboards.secondPieceB |= uint256(bitboards[uint(Piece.Q)]) << 64;
        eBitboards.secondPieceB |= uint256(bitboards[uint(Piece.K)]);

        // handling third piece
        eBitboards.thirdPieceB |= uint256(bitboards[uint(Piece.P)]) << 192;
        eBitboards.thirdPieceB |= uint256(bitboards[uint(Piece.N)]) << 128;
        eBitboards.thirdPieceB |= uint256(bitboards[uint(Piece.B)]) << 64;
        eBitboards.thirdPieceB |= uint256(bitboards[uint(Piece.R)]);
    }

    // function updateAttackWithSquare(uint64 attackSquare, uint64 attacksBitboard) internal returns (uint64){
    //     uint64 sqPos = uint64(1) << attackSquare;
    //     return attacksBitboard |= sqPos;
    // }

    function getBishopAttacks(uint64 square, uint blockboard) internal pure returns (uint64 attacks){
        uint64 sr = square / 8;
        uint64 sf = square % 8;

        uint64 r = sr + 1;
        uint64 f = sf + 1;

        while (r <= 7 && f <= 7){
            uint64 sq = r * 8 + f;
            uint64 sqPos = uint64(1) << sq;
            if (sqPos & blockboard != 0) break;
            attacks |= sqPos;
            r += 1;
            f += 1;
        }

        if (f != 0){
            r = sr + 1;
            f = sf - 1;
            while (r <= 7){
                uint64 sq = r * 8 + f;
                uint64 sqPos = uint64(1) << sq;
                if (sqPos & blockboard != 0) break;
                attacks |= sqPos;
                r += 1;
                if (f == 0) break;
                f -= 1;
            }
        }

        if (r != 0){
            r = sr - 1;
            f = sf + 1;
            while (f <= 7){
                uint64 sq = r * 8 + f;
                uint64 sqPos = uint64(1) << sq;
                if (sqPos & blockboard != 0) break;
                attacks |= sqPos;
                f += 1;
                if (r == 0) break;
                r -= 1;
            }
        }

        if (r != 0 && f != 0){
            r = sr - 1;
            f = sf - 1;
            while (true){
                uint64 sq = r * 8 + f;
                uint64 sqPos = uint64(1) << sq;
                if (sqPos & blockboard != 0) break;
                attacks |= sqPos;
                if (r == 0 || f == 0) break;
                r -= 1;
                f -= 1;
            }
        }
    }

    function getRookAttacks(uint64 square, uint blockboard) internal pure returns (uint64 attacks) {
        uint64 sr = square / 8;
        uint64 sf = square % 8;

        uint64 r = sr + 1;
        uint64 f;

        while (r <= 7){
            uint64 sq = r * 8 + sf;
            uint64 sqPos = uint64(1) << sq;
            if (sqPos & blockboard != 0) break;
            attacks |= sqPos;
            r += 1;
        }

        f = sf + 1;
        while (f <= 7){
            uint64 sq = sr * 8 + f;
            uint64 sqPos = uint64(1) << sq;
            if (sqPos & blockboard != 0) break;
            attacks |= sqPos;
            f += 1;
        }

        if (sr != 0){
            r = sr - 1;
            while (true){
                uint64 sq = r * 8 + sf;
                uint64 sqPos = uint64(1) << sq;
                if (sqPos & blockboard != 0) break;
                attacks |= sqPos;
                if (r == 0) break;
                r -= 1;
            }
        }

        if (sf != 0){
            f = sf - 1;
            while (true){
                uint64 sq = sr * 8 + f;
                uint64 sqPos = uint64(1) << sq;
                if (sqPos & blockboard != 0) break;
                attacks |= sqPos;
                if (f == 0) break;
                f -= 1;
            }
        }
    }

    function isSquareAttacked(uint64 square, Piece piece, uint64[12] memory bitboards, uint blockboard) internal view returns (bool){
        if (piece == Piece.uk){
            return false;
        }

        uint side;
        if (uint(piece) < 6){
            side = 1;
        }

        // check black pawn attacks on sq
        if (side == 0 && whitePawnAttacks[square] & bitboards[uint(Piece.p)] != 0) {
            return true;
        }

        // check white pawn attacks on sq
        if (side == 1 && blackPawnAttacks[square] & bitboards[uint(Piece.P)] != 0) {
            return true;
        }

        // check kings attacks on sq
        if (kingAttacks[square] & (side == 0 ? bitboards[uint(Piece.k)] : bitboards[uint(Piece.K)]) != 0) {
            return true;
        }

        // check knight attacks on sq
        if (knightAttacks[square] & (side == 0 ? bitboards[uint(Piece.n)] : bitboards[uint(Piece.N)]) != 0){
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

    function decodeMove(uint24 moveValue, uint64[12] memory bitboards) internal pure returns (Move memory move) {
        move.sourceSq = moveValue & 63;
        move.targetSq = moveValue & 4032 >> 6;

        uint pawnPromotion = moveValue & 61440 >> 12;
        move.promotedToPiece = Piece.uk;

        // move flag
        uint doublePushFlag = moveValue & 65536 >> 16;
        uint enpassantFlag = moveValue & 131072 >> 17;
        uint castleFlag = moveValue & 262144 >> 18;
        uint sumFlags = doublePushFlag + enpassantFlag + castleFlag;
        
        require(pawnPromotion > 0 && pawnPromotion < 12 && sumFlags == 0 || sumFlags == 1 && pawnPromotion == 0 || pawnPromotion == 0 && sumFlags == 0, "Invalid flags");

        MoveFlag moveFlag = MoveFlag.NoFlag;
        if (pawnPromotion != 0){
            moveFlag = MoveFlag.PawnPromotion;
            move.promotedToPiece = Piece(pawnPromotion);
        }else if (doublePushFlag == 1){
            moveFlag = MoveFlag.DoublePush;
        }else if (enpassantFlag == 1){
            moveFlag = MoveFlag.Enpassant;
        }else if (castleFlag == 1){
            moveFlag = MoveFlag.Castle;
        }
        move.moveFlag = moveFlag;

        if (move.targetSq > move.sourceSq){
            move.moveBySq = move.targetSq - move.sourceSq;
            move.moveLeftShift = true;
        }else if ( move.targetSq < move.sourceSq){
            move.moveBySq = move.sourceSq - move.targetSq;
            move.moveLeftShift = false;
        }
        require(move.targetSq != move.sourceSq, "No move");

        // find the piece being moved
        move.sourcePiece = Piece.uk;
        move.targetPiece = Piece.uk;
        move.sourcePieceBitBoard = uint64(1) << move.sourceSq;
        move.targetPieceBitBoard = uint64(1) << move.targetSq;
        for (uint64 index = 1; index < bitboards.length; index++) {
            uint64 board = bitboards[index];
            if ((move.sourcePieceBitBoard & board)>0){
                move.sourcePiece = Piece(index);
            }
            if ((move.targetPieceBitBoard & board)>0){
                move.targetPiece = Piece(index);
            }
        }
        require(move.sourcePiece != Piece.uk, "Unknown Piece");
    }

    function getBlockerBoard(uint64[12] memory bitboards) internal pure returns (uint64 blockerboard){
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

    function getWhiteboard(uint64[12] memory bitboards) internal pure returns (uint64){
        uint64 board;
        board |= bitboards[uint(Piece.P)];
        board |= bitboards[uint(Piece.N)];
        board |= bitboards[uint(Piece.B)];
        board |= bitboards[uint(Piece.R)];
        board |= bitboards[uint(Piece.Q)];
        board |= bitboards[uint(Piece.K)];
        return board;
    }

    function getBlackboard(uint64[12] memory bitboards) internal pure returns (uint64){
        uint64 board;
        board |= bitboards[uint(Piece.p)];
        board |= bitboards[uint(Piece.n)];
        board |= bitboards[uint(Piece.b)];
        board |= bitboards[uint(Piece.r)];
        board |= bitboards[uint(Piece.q)];
        board |= bitboards[uint(Piece.k)];
        return board;
    }

    function isMoveValid(GameState memory gameState, uint64[12] memory bitboards, Move memory move) public view returns (bool) {    
        // source piece should match playing side
        if (gameState.side == 0 && uint(move.sourcePiece) < 6){
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

        uint64 blockerboard = getBlockerBoard(bitboards);

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
                    if (1 << 63 & bitboards[uint(Piece.R)] == 0){
                        return false;
                    }

                    // no attacks to king and thru passage
                    if (
                        isSquareAttacked(60, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(61, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(62, move.sourcePiece, bitboards, blockerboard)
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
                    if (1 << 56 & bitboards[uint(Piece.R)] == 0){
                        return false;
                    }

                    // no attacks to king and thru passage
                    if (
                        isSquareAttacked(60, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(59, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(58, move.sourcePiece, bitboards, blockerboard)
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
                    if (1 << 7 & bitboards[uint(Piece.r)] == 0){
                        return false;
                    }

                    // no attacks on king sq & thru sqaures
                    if (
                        isSquareAttacked(4, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(5, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(6, move.sourcePiece, bitboards, blockerboard) 
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
                    if (1 & bitboards[uint(Piece.r)] == 0){
                        return false;
                    }

                    // no attacks on king sq & thru squares
                    if (
                        isSquareAttacked(4, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(3, move.sourcePiece, bitboards, blockerboard) ||
                        isSquareAttacked(2, move.sourcePiece, bitboards, blockerboard) 
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

            return true;
        }

        if (move.moveFlag == MoveFlag.DoublePush){
            // should be pawn
            if (move.sourcePiece != Piece.P && move.sourcePiece != Piece.p){
                return false;
            }

            // mmoveBy should be 16
            if (move.moveBySq != 16){
                return false;
            }

            // white pawn
            if (move.sourcePiece == Piece.P){
                // move upwards
                if (move.moveLeftShift != false){
                    return false;
                }

                // pawn shouldn't have moved before; 
                // 71776119061217280 is initial pos of white pawns on board
                if (move.sourcePieceBitBoard & 71776119061217280 == 0){
                    return false;
                }
            }

            // black pawn
            if (move.sourcePiece == Piece.p){
                // move downwards
                if (move.moveLeftShift != true){
                    return false;
                }

                // pawn shouldn't have moved before; 
                // 65280 is initial pos of black pawns on board
                if (move.sourcePieceBitBoard & 65280 == 0){
                    return false;
                }
            } 

            return true;
        }

        uint enPassanSq;
        if (move.moveFlag == MoveFlag.Enpassant){
            if (enPassanSq == 0 || move.targetSq != enPassanSq || (move.sourcePiece != Piece.P && move.sourcePiece != Piece.p)){
                return false;
            }

            if (move.moveBySq != 9 && move.moveBySq != 7){
                return false;
            }

            // white pawn
            if (move.sourcePiece == Piece.P){
                // move upwards
                if (move.moveLeftShift != false){
                    return false;
                }
            }

            // black pawn
            if (move.sourcePiece == Piece.p){
                // move downwards
                if (move.moveLeftShift != true){
                    return false;
                }
            }
        }

        // king
        if (move.sourcePiece == Piece.K && move.moveFlag == MoveFlag.NoFlag){
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
        if ((move.sourcePiece == Piece.K || move.sourcePiece == Piece.k) && move.moveFlag == MoveFlag.NoFlag) {
            if (move.moveBySq != 17 && move.moveBySq != 15 && move.moveBySq != 6 && move.moveBySq != 10) {
                return false;
            }

            // downwards
            if (move.moveLeftShift == true){
                // check falling off right edge
                if (move.moveBySq == 17 && (move.sourcePieceBitBoard <<  17 & notAFile) == 0){
                    return false;
                }

                // check falling off right edge (2 lvl deep)
                if (move.moveBySq == 10 && (move.sourcePieceBitBoard <<  10 & notABFile) == 0){
                    return false;
                }

                // check falling off left edge
                if (move.moveBySq == 15 && (move.sourcePieceBitBoard <<  15 & notHFile) == 0){
                    return false;
                }

                // check falling off left edge (2 lvl deep)
                if (move.moveBySq == 6 && (move.sourcePieceBitBoard <<  6 & notHGFile) == 0){
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
        
        // white pawns
        if (move.sourcePiece == Piece.P && (move.moveFlag == MoveFlag.NoFlag || move.moveFlag == MoveFlag.PawnPromotion)){
            if (move.moveBySq != 8 && move.moveBySq != 9 && move.moveBySq != 7){
                return false;
            }

            // cannot move diagnol (i.e attack), unless target piece exists
            if ((move.moveBySq == 9 || move.moveBySq == 7) && move.targetPiece == Piece.uk){
                return false;
            }

            // white pawns can only move upwards
            if (move.moveLeftShift != false){
                return false;
            }

            // cannot move forward if something is in front
            if (move.moveBySq == 8 && (uint64(1) << move.sourceSq - 8 & blockerboard) > 0){
                return false;
            }

            // cannot go out of the board; white pawns can't move forward when on rank 8
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

            // check for promotion
            if (move.moveFlag == MoveFlag.PawnPromotion){
                // promoted piece cannot be unkown, cannot be a pawn, cannot be a black piece
                if (move.promotedToPiece == Piece.uk || uint(move.promotedToPiece) < 6 || move.promotedToPiece == Piece.P){
                    return false;
                }

                // current rank should be 1
                if (move.sourceSq / 8 != 1){
                    return false;
                }
            }
        }   

        // black pawns
        if (move.sourcePiece == Piece.p && (move.moveFlag == MoveFlag.NoFlag || move.moveFlag == MoveFlag.PawnPromotion)){
            if (move.moveBySq != 8 && move.moveBySq != 9 && move.moveBySq != 7){
                return false;
            }

            // cannot move diagnol, unless target piece exists
            if ((move.moveBySq == 9 || move.moveBySq == 7) && move.targetPiece == Piece.uk){
                return false;
            }

            // black pawns can only move downwards
            if (move.moveLeftShift != true){
                return false;
            }

            // cannot move forward if something is in front
            if (move.moveBySq == 8 && (uint64(1) << move.sourceSq + 8 & blockerboard) > 0){
                return false;
            }


            // cannot go out of the board; black pawns can't move forward when on rank 1
            if (move.sourcePieceBitBoard << move.moveBySq == 0){
                return false;
            }

            // check falling off right edge
            if (move.moveBySq == 9 && (move.sourcePieceBitBoard << 9 & notAFile) == 0){
                return false;
            }

            // check falling off right edge
            if (move.moveBySq == 7 && (move.sourcePieceBitBoard << 7 & notHFile) == 0){
                return false;
            }

            // check for promotion
            if (move.moveFlag == MoveFlag.PawnPromotion){
                // promoted piece cannot be unkown, cannot be a pawn, cannot be a white piece
                if (move.promotedToPiece == Piece.uk || uint(move.promotedToPiece) >= 6 || move.promotedToPiece == Piece.p){
                    return false;
                }

                // current rank should be 6
                if (move.sourceSq / 8 != 6){
                    return false;
                }
            }
        } 

        // queen
        if ((move.sourcePiece == Piece.Q || move.sourcePiece == Piece.q) && move.moveFlag == MoveFlag.NoFlag){
            // if rank or file matches, then move is like a rook, otherwise bishop
            if ((move.sourceSq % 8 == move.targetSq % 8) || (move.sourceSq / 8 == move.targetSq / 8)){
                move.sourcePiece == Piece.R;
            }else {
                move.sourcePiece == Piece.B;
            }
        }
    
        // bishop
        if ((move.sourcePiece == Piece.B || move.sourcePiece == Piece.b) && move.moveFlag == MoveFlag.NoFlag) {
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

        // rook
        if ((move.sourcePiece == Piece.R || move.sourcePiece == Piece.r) && move.moveFlag == MoveFlag.NoFlag) {
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
    }

    function applyMove(uint24 moveValue) external {
        GameState memory gameState;
        EncodedBitboards memory encodedBitboards;
        uint64[12] memory bitboards = decodeBitboards(encodedBitboards);

        Move memory move = decodeMove(moveValue, bitboards);

        // check whether move is valid
        require(isMoveValid(gameState, bitboards, move));

        // check game over
        if (move.targetPiece == Piece.K){
            // black won
            gameState.winner = 1;
            // TODO update game state
            
        }else if (move.targetPiece == Piece.k){
            // white won
            gameState.winner = 0;

            // TODO update game state
        }
        // game not over
        else {
            // update source piece pos to target sq
            bitboards[uint(move.sourcePiece)] = (bitboards[uint(move.sourcePiece)] | uint64(1) << move.targetSq) & ~uint64(1) << move.sourceSq;

            // remove target piece from target sq
            if (move.targetPiece != Piece.uk ){
                bitboards[uint(move.targetPiece)] &= ~uint64(1) << move.targetSq;
            }

            // update pawn promotion
            if (move.moveFlag == MoveFlag.PawnPromotion){
                // add promoted piece at target sq
                bitboards[uint(move.promotedToPiece)] |= uint64(1) << move.targetSq;
                // remove pawn from target sq
                bitboards[uint(move.sourcePiece)] &= ~uint64(1) << move.targetSq;
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

            // TODO update game state and bitboards
        }
    }
}
/**
    Move bits
    0000 0000 0000 0011 1111 source sq
    0000 0000 1111 1100 0000 target sq
    0000 1111 0000 0000 0000 promoted piece
    0001 0000 0000 0000 0000 double push flag
    0010 0000 0000 0000 0000 enpassant flat
    0100 0000 0000 0000 0000 castle flag
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
    