// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "ds-test/test.sol";

contract Chess is DSTest {

    // 12 boards

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

    // uint256[12] bitboards = [
    //     // black pos
    //     65280,
    //     66,
    //     36,
    //     1,
    //     8,
    //     16,
    //     // white pos
    //     71776119061217280,
    //     4755801206503243776,
    //     1297036692682702848,
    //     36028797018963968,
    //     576460752303423488,
    //     1152921504606846976
    // ];

    // function eall() internal returns (uint){
    //     return 256;
    // }

    // function test_ecall() external {
    //     uint f = eall();
    // }
    // function test_3ecall() external {
    //     uint f = 256;
    // }


    function decodeMove(uint24 moveValue, uint64[12] memory bitboards) internal returns (Move memory move) {
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

    function test_isMoveValid() public returns (bool) {
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

        // king
        if (move.sourcePiece == Piece.K){
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
        if (move.sourcePiece == Piece.K || move.sourcePiece == Piece.k) {
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

        // blockerBitboard 
        uint64 blockerBoard = getBlockerBoard(bitboards);

        // white pawns
        if (move.sourcePiece == Piece.P){
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
        }   

        // black pawns
        if (move.sourcePiece == Piece.p){
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
        } 

        // queen
        if (move.sourcePiece == Piece.Q || move.sourcePiece == Piece.q){
            // if rank or file matches, then move is like a rook, otherwise bishop
            if ((move.sourceSq % 8 == move.targetSq % 8) || (move.sourceSq / 8 == move.targetSq / 8)){
                move.sourcePiece == Piece.R;
            }else {
                move.sourcePiece == Piece.B;
            }
        }
    
        // bishop
        if (move.sourcePiece == Piece.B || move.sourcePiece == Piece.b) {
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
        if (move.sourcePiece == Piece.R || move.sourcePiece == Piece.r) {
            uint sr = move.sourceSq / 8; 
            uint sf = move.sourceSq % 8;
            uint tr = move.targetSq / 8; 
            uint tf = move.targetSq % 8;
            
            bool targetFound = false;

            // check target is daigonal & there exist no blockers
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
            if (sr == tr && sf > tf) {
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
            if (sr > tr && sf == tf) {
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

            // if targetSq not found, then targetSq isn't positioned diagonally to bishop's pos
            require(targetFound);
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
    