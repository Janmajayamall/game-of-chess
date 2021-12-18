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

    struct EncodedBoardState {
        uint256 firstPieceB; // p, n, b, r 
        uint256 secondPieceB; // q, k, Q, K
        uint256 thirdPieceB; // P, N, B, R
        uint8 castlings; // wq, wk, bq, bk,
        uint64 enpassantSq;
    }

    struct BoardState {
        uint64[12] bitboard;

        // castling rights
        bool bkC;
        bool bqC;
        bool wkC;
        bool wqC;

        // enpassant
        uint64 enpassantSq;
    }


    /**
        6 white bitboards
        6 black bitboards

        castling rights wq wk bq bk 

        enpassant
     */

    // attacking squares of non-sliding pieces
    mapping(uint => uint64) whitePawnAttacks;
    mapping(uint => uint64) blackPawnAttacks;
    mapping(uint => uint64) kingAttacks;
    mapping(uint => uint64) knightAttacks;

    function decodeBoardState(EncodedBoardState memory eboardState) internal pure returns(BoardState memory boardState) {
        // handling first piece
        boardState.bitboard[uint(Piece.r)] = uint64(eboardState.firstPieceB);
        boardState.bitboard[uint(Piece.b)] = uint64(eboardState.firstPieceB >> 64);
        boardState.bitboard[uint(Piece.n)] = uint64(eboardState.firstPieceB >> 128);
        boardState.bitboard[uint(Piece.p)] = uint64(eboardState.firstPieceB >> 192);

        // handling second piece
        boardState.bitboard[uint(Piece.K)] = uint64(eboardState.secondPieceB);
        boardState.bitboard[uint(Piece.Q)] = uint64(eboardState.secondPieceB >> 64);
        boardState.bitboard[uint(Piece.k)] = uint64(eboardState.secondPieceB >> 128);
        boardState.bitboard[uint(Piece.q)] = uint64(eboardState.secondPieceB >> 192);

        // handling third piece
        boardState.bitboard[uint(Piece.R)] = uint64(eboardState.thirdPieceB);
        boardState.bitboard[uint(Piece.B)] = uint64(eboardState.thirdPieceB >> 64);
        boardState.bitboard[uint(Piece.N)] = uint64(eboardState.thirdPieceB >> 128);
        boardState.bitboard[uint(Piece.P)] = uint64(eboardState.thirdPieceB >> 192);

        // castling rights
        boardState.bkC = eboardState.castlings & 1 != 0;
        boardState.bqC = eboardState.castlings >> 1 & 1 != 0;
        boardState.wkC = eboardState.castlings >> 2 & 1 != 0;
        boardState.wqC = eboardState.castlings >> 3 & 1 != 0;

        boardState.enpassantSq = eboardState.enpassantSq;
    }

    function encodeBoardState(BoardState memory boardState) internal pure returns(EncodedBoardState memory eboardState){
        // handling first piece
        eboardState.firstPieceB |= uint256(boardState.bitboard[uint(Piece.p)]) << 192;
        eboardState.firstPieceB |= uint256(boardState.bitboard[uint(Piece.n)]) << 128;
        eboardState.firstPieceB |= uint256(boardState.bitboard[uint(Piece.b)]) << 64;
        eboardState.firstPieceB |= uint256(boardState.bitboard[uint(Piece.r)]);

        // handling second piece
        eboardState.secondPieceB |= uint256(boardState.bitboard[uint(Piece.q)]) << 192;
        eboardState.secondPieceB |= uint256(boardState.bitboard[uint(Piece.k)]) << 128;
        eboardState.secondPieceB |= uint256(boardState.bitboard[uint(Piece.Q)]) << 64;
        eboardState.secondPieceB |= uint256(boardState.bitboard[uint(Piece.K)]);

        // handling third piece
        eboardState.thirdPieceB |= uint256(boardState.bitboard[uint(Piece.P)]) << 192;
        eboardState.thirdPieceB |= uint256(boardState.bitboard[uint(Piece.N)]) << 128;
        eboardState.thirdPieceB |= uint256(boardState.bitboard[uint(Piece.B)]) << 64;
        eboardState.thirdPieceB |= uint256(boardState.bitboard[uint(Piece.R)]);

        // castling rights
        eboardState.castlings |= boardState.wqC ? 1 << 3 : 0;
        eboardState.castlings |= boardState.wkC ? 1 << 2 : 0;
        eboardState.castlings |= boardState.bqC ? 1 << 1 : 0;
        eboardState.castlings |= boardState.bkC ? 1 : 0;

        eboardState.enpassantSq = boardState.enpassantSq;
    }

    function updateAttackWithSquare(uint64 attackSquare, uint64 attacksBitboard) internal returns (uint64){
        uint64 sqPos = uint64(1) << attackSquare;
        return attacksBitboard |= sqPos;
    }

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

    function getBlockerBoard(uint64[12] memory bitboards) internal pure returns (uint64 blockerBoard){
        blockerBoard |= bitboards[uint(Piece.p)];
        blockerBoard |= bitboards[uint(Piece.n)];
        blockerBoard |= bitboards[uint(Piece.b)];
        blockerBoard |= bitboards[uint(Piece.r)];
        blockerBoard |= bitboards[uint(Piece.q)];
        blockerBoard |= bitboards[uint(Piece.k)];

        blockerBoard |= bitboards[uint(Piece.P)];
        blockerBoard |= bitboards[uint(Piece.N)];
        blockerBoard |= bitboards[uint(Piece.B)];
        blockerBoard |= bitboards[uint(Piece.R)];
        blockerBoard |= bitboards[uint(Piece.Q)];
        blockerBoard |= bitboards[uint(Piece.K)];
    }

    function test_isMoveValid() public view returns (bool) {
        // accept a move, extract source and target -> store then in 3 uint256s 
        uint64[12] memory bitboards =  [
            // black pos
            65280,
            66,
            36,
            129,
            8,
            16,
            // white pos
            71776119061217280,
            4755801206503243776,
            2594073385365405696,
            9295429630892703744,
            576460752303423488,
            1152921504606846976
        ];

    
        // not files, for move validations
        uint64 notAFile = 18374403900871474942;
        uint64 notHFile = 9187201950435737471;
        uint64 notHGFile = 4557430888798830399;
        uint64 notABFile = 18229723555195321596;

        // for a normal piece move

        // uint side = 0; // white = 0; black = 1
        

        // // check that target isn't occupied by some piece on the same side
        // if (side == 0 && (1 << targetSq & whiteBoard) > 0){
        //     return false;
        // }
        // if (side == 1 && (1 << targetSq & blackBoard) > 0){
        //     return false;
        // }

        /**
        Check that target piece & source piece do not belong to the same side
         */
        // // piece present does not belongs to the playing side
        // if ((side == 0 && uint(sourcePiece) < 6 )||( side == 1 && uint(sourcePiece) >= 6 )){
        //     return false;
        // }

        // (
        //     uint64 sourceSq, 
        //     uint64 targetSq, 
        //     uint64 moveBySq, 
        //     bool moveLeftShift,
        //     Piece sourcePiece,
        //     Piece targetPiece,
        //     uint64 sourcePieceBitBoard,
        // ) = decodeMove(23, bitboards);

        Move memory move = decodeMove(23, bitboards);

        // blockerBitboard 
        uint64 blockerBoard = getBlockerBoard(bitboards);

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
                    // rook should be on original pos
                    if (1 << 63 & bitboards[uint(Piece.R)] == 0){
                        return false;
                    }

                    // TODO king & rook should not have moved

                    // no attacks to king and thru passage
                    if (
                        isSquareAttacked(60, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(61, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(62, move.sourcePiece, bitboards, blockerBoard)
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 61 & blockerBoard != 0 ||
                        1 << 62 & blockerBoard != 0
                    ){
                        return false;
                    }
                }

                // queen side castling
                if (move.targetSq == 58){
                    // rook should on original pos
                    if (1 << 56 & bitboards[uint(Piece.R)] == 0){
                        return false;
                    }

                    // TODO king & rook should not have moved

                     // no attacks to king and thru passage
                    if (
                        isSquareAttacked(60, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(59, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(58, move.sourcePiece, bitboards, blockerBoard)
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 57 & blockerBoard != 0 ||
                        1 << 58 & blockerBoard != 0 ||
                        1 << 59 & blockerBoard != 0
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
                    // rook should be on 7
                    if (1 << 7 & bitboards[uint(Piece.r)] == 0){
                        return false;
                    }

                    // TODO king & rook should not have moved

                    // no attacks on king sq & thru sqaures
                    if (
                        isSquareAttacked(4, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(5, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(6, move.sourcePiece, bitboards, blockerBoard) 
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 5 & blockerBoard != 0 ||
                        1 << 6 & blockerBoard != 0
                    ){
                        return false;
                    }
                }


                // queen side castling
                if (move.targetSq == 2){
                    // rook should be on 0 
                    if (1 & bitboards[uint(Piece.r)] == 0){
                        return false;
                    }

                    // TODO king & rook should not have moved

                    // no attacks on king sq & thru squares
                    if (
                        isSquareAttacked(4, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(3, move.sourcePiece, bitboards, blockerBoard) ||
                        isSquareAttacked(2, move.sourcePiece, bitboards, blockerBoard) 
                    ){
                        return false;
                    }

                    // passage should be empty
                    if (
                        1 << 3 & blockerBoard != 0 ||
                        1 << 2 & blockerBoard != 0 ||
                        1 << 1 & blockerBoard != 0
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
            if (move.moveBySq == 8 && (uint64(1) << move.sourceSq - 8 & blockerBoard) > 0){
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
                // promoted piece should be given
                if (move.promotedToPiece == Piece.uk){
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
            if (move.moveBySq == 8 && (uint64(1) << move.sourceSq + 8 & blockerBoard) > 0){
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
                // promoted piece should be given
                if (move.promotedToPiece == Piece.uk){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
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
                    if ((uint(1) << sq & blockerBoard) > 0){
                        break;
                    }
                    r += 1;
                }
            }


            // if targetSq not found, then targetSq isn't valid
            if (targetFound == false) return false;
        }
    }

    function applyMove() external {
         uint64[12] memory bitboards =  [
            // black pos
            65280,
            66,
            36,
            129,
            8,
            16,
            // white pos
            71776119061217280,
            4755801206503243776,
            2594073385365405696,
            9295429630892703744,
            576460752303423488,
            1152921504606846976
        ];
        // (
        //     uint64 sourceSq, 
        //     uint64 targetSq, 
        //     uint64 moveBySq, 
        //     bool moveLeftShift,
        //     Piece sourcePiece,
        //     Piece targetPiece,
        //     uint64 sourcePieceBitBoard,
        // ) = decodeMove(23, bitboards);

        // require(test_isMoveValid(), "Invalid move");

        // // update source pos
        // bitboards[uint(sourcePiece)] = (bitboards[uint(sourcePiece)] | uint64(1) << targetSq) & ~uint64(1) << sourceSq;

        // // remove target piece, if it exists
        // if (targetPiece != Piece.uk){
        //     bitboards[uint(targetPiece)] = bitboards[uint(targetPiece)] & ~(uint64(1) << targetSq);
        // }
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
    