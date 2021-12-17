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

    uint  r= 2;

    function getFF() internal returns(uint){
        return 2;
    }


    function test_isMoveValid() external returns (bool) {
        uint side = 0;
        uint sourceSq = 0;
        uint targetSq = 0;
        uint moveBySq = 0;
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

        // not files
        // not A file constant
        uint64 notAFile = 18374403900871474942;
        uint64 notHFile = 9187201950435737471;
        uint64 notHGFile = 4557430888798830399;
        uint64 notABFile = 18229723555195321596;

        // for a normal piece move


        // check that target isn't occupied by some piece on the same side
        if (side == 0 && (1 << targetSq & whiteBoard) > 0){
            return false;
        }
        if (side == 1 && (1 << targetSq & blackBoard) > 0){
            return false;
        }

        // check is transition valid depending on the piece being moved
        // find the piece being moved
        Piece sourcePiece = Piece.uk;
        uint64 sourcePieceBitBoard;
        for (uint64 index = 1; index < bitboards.length; index++) {
            uint64 board = bitboards[index];
            if ((1 << sourceSq & board)>0){
                // piece exists
                sourcePiece = Piece(index);
                sourcePieceBitBoard = bitboards[index];
            }
        }
        // no piece present at sourceSq
        if (sourcePiece == Piece.uk){
            return false;
        }
        // piece present does not belongs to the playing side
        if ((side == 0 && uint(sourcePiece) < 6 )||( side == 1 && uint(sourcePiece) >= 6 )){
            return false;
        }


        if (sourcePiece == Piece.K){
            // moveBy can only be 8, 9, 7, 1
            if (moveBySq != 8 || moveBySq != 9 || moveBySq != 7 || moveBySq != 1){
                return false;
            }

            // can only move inside the board
            if (sourcePieceBitBoard << uint64(moveBySq) == 0){
                return false;
            }

            // check falling off right edge
            if (moveBySq == 7 && (sourcePieceBitBoard << 9 & notAFile) == 0){
                return false;
            }

            // check falling off left edge
            if (moveBySq == 9 && (sourcePieceBitBoard << 9 & notHFile) == 0){
                return false;
            }
        }


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
    