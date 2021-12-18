// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IChess {
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
}