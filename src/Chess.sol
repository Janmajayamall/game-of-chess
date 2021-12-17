// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "ds-test/test.sol";

contract Chess is DSTest {

    // 12 boards

    enum Piece { 
        p, n, b, r, q, k, P, N, B, R, Q, K, uk
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


    function test_isMoveValid() external returns (bool) {
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

        // black board
        uint64 blackBoard = bitboards[uint(Piece.p)];
        blackBoard |= bitboards[uint(Piece.n)];
        blackBoard |= bitboards[uint(Piece.b)];
        blackBoard |= bitboards[uint(Piece.r)];
        blackBoard |= bitboards[uint(Piece.q)];
        blackBoard |= bitboards[uint(Piece.k)];

        // black board
        uint64 whiteBoard = bitboards[uint(Piece.P)];
        whiteBoard |= bitboards[uint(Piece.N)];
        whiteBoard |= bitboards[uint(Piece.B)];
        whiteBoard |= bitboards[uint(Piece.R)];
        whiteBoard |= bitboards[uint(Piece.Q)];
        whiteBoard |= bitboards[uint(Piece.K)];

    
        // not files, for move validations
        uint64 notAFile = 18374403900871474942;
        uint64 notHFile = 9187201950435737471;
        uint64 notHGFile = 4557430888798830399;
        uint64 notABFile = 18229723555195321596;

        // for a normal piece move

        // uint side = 0; // white = 0; black = 1
        uint64 sourceSq = 0;
        uint64 targetSq = 0;
        uint64 moveBySq = 0;
        bool moveLeftShift = false; // left shift is down the board & right shift is up the board
        if ( targetSq > sourceSq){
            moveBySq = targetSq - sourceSq;
            moveLeftShift = true;
        }else if ( targetSq < sourceSq){
            moveBySq = sourceSq - targetSq;
            moveLeftShift = false;
        }
        if (moveBySq == 0){
            return false; // no move specified
        }

        // // check that target isn't occupied by some piece on the same side
        // if (side == 0 && (1 << targetSq & whiteBoard) > 0){
        //     return false;
        // }
        // if (side == 1 && (1 << targetSq & blackBoard) > 0){
        //     return false;
        // }

        // check is transition valid depending on the piece being moved
        // find the piece being moved
        Piece sourcePiece = Piece.uk;
        Piece targetPiece = Piece.uk;
        uint64 sourcePieceBitBoard;
        for (uint64 index = 1; index < bitboards.length; index++) {
            uint64 board = bitboards[index];
            if ((1 << sourceSq & board)>0){
                // piece exists
                sourcePiece = Piece(index);
                sourcePieceBitBoard = uint64(1) << sourceSq;
            }
        }
        // no piece present at sourceSq
        if (sourcePiece == Piece.uk){
            return false;
        }

        /**
        Check that target piece & source piece do not belong to the same side
         */
        // // piece present does not belongs to the playing side
        // if ((side == 0 && uint(sourcePiece) < 6 )||( side == 1 && uint(sourcePiece) >= 6 )){
        //     return false;
        // }


        if (sourcePiece == Piece.K){
            // moveBy can only be 8, 9, 7, 1
            if (moveBySq != 8 && moveBySq != 9 && moveBySq != 7 && moveBySq != 1){
                return false;
            }

            // downwards
            if (moveLeftShift == true){
                // can only move inside the board
                if (sourcePieceBitBoard << uint64(moveBySq) == 0){
                    return false;
                }

                // check falling off right edge
                if (moveBySq == 9 && (sourcePieceBitBoard << 9 & notAFile) == 0){
                    return false;
                }

                // check falling off left edge
                if (moveBySq == 7 && (sourcePieceBitBoard << 7 & notHFile) == 0){
                    return false;
                }
            }

            // upwards
            if (moveLeftShift == false){
                // can only move inside the board
                if (sourcePieceBitBoard >> uint64(moveBySq) == 0){
                    return false;
                }

                // check falling off right edge
                if (moveBySq == 7 && (sourcePieceBitBoard >> 7 & notAFile) == 0){
                    return false;
                }

                // check falling off left edge 
                if (moveBySq == 9 && (sourcePieceBitBoard >> 9 & notHFile) == 0){
                    return false;
                }
            }
        }

        // white pawns
        if (sourcePiece == Piece.P){
            if (moveBySq != 8 && moveBySq != 9 && moveBySq != 7){
                return false;
            }

            // cannot move diagnol (i.e attack), unless target piece exists
            if ((moveBySq == 9 || moveBySq == 7) && targetPiece == Piece.uk){
                return false;
            }

            // TODO cannot move forward if something is in front

            // white pawns can only move upwards
            if (moveLeftShift != false){
                return false;
            }

            // cannot go out of the board; white pawns can't move forward when on rank 8
            if (sourcePieceBitBoard >> moveBySq == 0){
                return false;
            }

            // check falling off right edge
            if (moveBySq == 7 && (sourcePieceBitBoard >> 7 & notAFile) == 0){
                return false;
            }

            // check falling off left edge
            if (moveBySq == 9 && (sourcePieceBitBoard >> 9 & notHFile) == 0){
                return false;
            }
        }   

        // black pawns
        if (sourcePiece == Piece.p){
            if (moveBySq != 8 && moveBySq != 9 && moveBySq != 7){
                return false;
            }

            // cannot move diagnol, unless target piece exists
            if ((moveBySq == 9 || moveBySq == 7) && targetPiece == Piece.uk){
                return false;
            }

            // black pawns can only move downwards
            if (moveLeftShift != true){
                return false;
            }

            // cannot go out of the board; black pawns can't move forward when on rank 1
            if (sourcePieceBitBoard << moveBySq == 0){
                return false;
            }

            // check falling off right edge
            if (moveBySq == 9 && (sourcePieceBitBoard << 9 & notAFile) == 0){
                return false;
            }

            // check falling off right edge
            if (moveBySq == 7 && (sourcePieceBitBoard << 7 & notHFile) == 0){
                return false;
            }
        } 

        // knight
        if (sourcePiece == Piece.K || sourcePiece == Piece.k) {
            if (moveBySq != 17 && moveBySq != 15 && moveBySq != 6 && moveBySq != 10) {
                return false;
            }

            // downwards
            if (moveLeftShift == true){
                // check falling off right edge
                if (moveBySq == 17 && (sourcePieceBitBoard <<  17 & notAFile) == 0){
                    return false;
                }

                // check falling off right edge (2 lvl deep)
                if (moveBySq == 10 && (sourcePieceBitBoard <<  10 & notABFile) == 0){
                    return false;
                }

                // check falling off left edge
                if (moveBySq == 15 && (sourcePieceBitBoard <<  15 & notHFile) == 0){
                    return false;
                }

                // check falling off left edge (2 lvl deep)
                if (moveBySq == 6 && (sourcePieceBitBoard <<  6 & notHGFile) == 0){
                    return false;
                }
            }

            // upwards
            if (moveLeftShift == false){
                // check falling off right edge
                if (moveBySq == 15 && (sourcePieceBitBoard >> 15 & notAFile) == 0){
                    return false;
                }

                // check falling off right edgen (2 lvl deep)
                if (moveBySq == 6 && (sourcePieceBitBoard >> 6 & notABFile) == 0){
                    return false;
                }

                // check falling off left edge
                if (moveBySq == 17 && (sourcePieceBitBoard >> 17 & notHFile) == 0){
                    return false;
                }

                // check falling off left edge (2 lvl deep)
                if (moveBySq == 10 && (sourcePieceBitBoard >> 10 & notHGFile) == 0){
                    return false;
                }
            }

        }

        // blockerBitboard 

    
        // bishop
        if (sourcePiece == Piece.B || sourcePiece == Piece.b) {
            uint _sourceSq = sourceSq;
            uint _targetSq = targetSq;
            uint _blockerBoard = whiteBoard | blackBoard;
            {
                uint sr = _sourceSq / 8; 
                uint sf = _sourceSq % 8;
                uint tr = _targetSq / 8; 
                uint tf = _targetSq % 8;
                
                bool targetFound = false;

                // check target is daigonal & there exist no blockers
                if (sr < tr && sf < tf){
                    uint r = sr + 1;
                    uint f = sf + 1;
                    while (r <= 7 && f <= 7){
                        uint sq = (r * 8) + f;

                        if (sq == targetSq){
                            targetFound = true;
                            break;
                        }

                        // check whether blocker exists
                        if ((uint(1) << sq & _blockerBoard) > 0){
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

                        if (sq == targetSq){
                            targetFound = true;
                            break;
                        }

                        // check for blocker at sq, if block exists then return false

                        r += 1;
                        if (f == 0){
                            break;
                        }
                        f -= 1;
                    }
                }
                if (sr > tr && sf > tf) {
                    uint r = sr + 1;
                    uint f = sf - 1;
                    while (r >= 0 && f >= 0){
                        uint sq = (r * 8) + f;

                        if (sq == targetSq){
                            targetFound = true;
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
                        
                        if (sq == targetSq){
                            targetFound = true;
                            break;
                        }

                        if (r == 0){
                            break;
                        }
                        r -= 1;
                        f += 1;
                    }
                }

                // if targetSq found, then targetSq isn't positioned diagonally to bishop's pos
                require(targetFound);
            }
            
        }

        // rook

        // queen

        emit log_uint(blackBoard);
        emit log_uint(whiteBoard);
    }
}

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
    