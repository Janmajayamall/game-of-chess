// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGocDataTypes {
    // 12 pieces
    enum Piece { 
        p, n, b, r, q, k, P, N, B, R, Q, K, uk
    }

    enum MoveFlag {
        NoFlag,
        Castle,
        PawnPromotion
    }

    struct MoveMetadata {
        uint256 side;
        uint16 gameId;
        uint16 moveCount;

        uint256 sourceSq;
        uint256 targetSq; 
        uint256 moveBySq; 

        uint64 sourcePieceBitBoard;
        uint64 targetPieceBitBoard;

        bool moveLeftShift; // left shift is down the board & right shift is up the board

        Piece sourcePiece;
        Piece targetPiece;
        Piece promotedToPiece;

        MoveFlag moveFlag;
    }

    struct GameState {
        // bitboards
        uint64[12] bitboards;

        // state
        uint8 state; // 0 -> uninitialised, 1 -> active, 2 -> ended

        // playing side
        uint8 side; // 0 -> white, 1 -> black


        // winner
        uint8 winner; // 0 -> white, 1 -> black, 2 -> draw

        // moves count
        uint16 moveCount;

        // halfmove clock
        uint16 halfMoveCount; 

        // enpassant
        uint64 enpassantSq;

        // castling rights
        bool bkC;
        bool bqC;
        bool wkC;
        bool wqC;
    }

    struct OutcomeReserves {
        uint reserve0;
        uint reserve1;
    }
}