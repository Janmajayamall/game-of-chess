// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../interfaces/IGocDataTypes.sol";
import "./../libraries/String.sol";
import "./../libraries/Uint.sol";

library GameParsers {
    using String for string;
    using Uint for uint;

    
    function parseUintToPieceChar(uint val) internal pure returns (string memory){
        require(val < 12, "Invalid Val");
        IGocDataTypes.Piece piece = IGocDataTypes.Piece(val);
        if (IGocDataTypes.Piece.p == piece){
            return string("p");
        }
        if (IGocDataTypes.Piece.n == piece){
            return string("n");
        }
        if (IGocDataTypes.Piece.b == piece){
            return string("b");
        }
        if (IGocDataTypes.Piece.r == piece){
            return string("r");
        }
        if (IGocDataTypes.Piece.q == piece){
            return string("q");
        }
        if (IGocDataTypes.Piece.k == piece){
            return string("k");
        }
        if (IGocDataTypes.Piece.P == piece){
            return string("P");
        }
        if (IGocDataTypes.Piece.N == piece){
            return string("N");
        }
        if (IGocDataTypes.Piece.B == piece){
            return string("B");
        }
        if (IGocDataTypes.Piece.R == piece){
            return string("R");
        }
        if (IGocDataTypes.Piece.Q == piece){
            return string("Q");
        }
        if (IGocDataTypes.Piece.K == piece){
            return string("K");
        }
    }

    function parseGameStateToFenString(IGocDataTypes.GameState memory gameState) internal pure returns (string memory fen){
        uint[] memory boardMap = new uint[](64);

        // make every index 12 for overlapping indentification
        for (uint256 index = 0; index < 64; index++) {
            boardMap[index] = 12;
        }

        for (uint256 pIndex = 0; pIndex < 12; pIndex++) {
            uint64 board = gameState.bitboards[pIndex];
            for (uint256 index = 0; index < 64; index++) {
                if (board & (1 << index) != 0){
                    require(boardMap[index] == 12, "Invalid board");
                    boardMap[index] = pIndex;
                }
            }
        }

        // convert board map to string
        uint emptySquares = 0;
        for (uint256 index = 0; index < 64; index++) {
            if (index % 8 == 0 && index != 0){
                if (emptySquares != 0){
                    fen = fen.append(emptySquares.toString());
                    emptySquares = 0;
                }
                fen = fen.append(string("/"));
            }

            // check empty sqaure
            if (boardMap[index] == 12){
                emptySquares += 1;
            }else {
                // append accumulated empty squares
                if (emptySquares != 0){
                    fen = fen.append(emptySquares.toString());
                    emptySquares = 0;
                }

                // append piece char
                fen = fen.append(parseUintToPieceChar(boardMap[index]));
            }
        }

        // side
        if (gameState.side == 0){
            fen = fen.append(" w ");
        }else {
            fen = fen.append(" b ");
        }

        // castling rights
        bool casltingAdded = false;
        if (gameState.wkC == true){
            fen = fen.append("K");
            casltingAdded = true;
        }
        if (gameState.wqC == true){
            fen = fen.append("Q");
            casltingAdded = true;
        }
        if (gameState.bkC == true){
            fen = fen.append("k");
            casltingAdded = true;
        }
        if (gameState.bqC == true){
            fen = fen.append("q");
            casltingAdded = true;
        }
        if (casltingAdded == false){
            fen = fen.append("-");
        }

        // enpassant sq
        fen = fen.append(" ");
        if (gameState.enpassantSq > 0){
            fen = fen.append(uint(gameState.enpassantSq).toString());
        }else{
            fen = fen.append("-");
        }
        fen = fen.append(" ");

        // half move count
        fen = fen.append(uint(gameState.halfMoveCount).toString());
        fen = fen.append(" ");

        // moves
        fen = fen.append(uint(gameState.moveCount/2).toString());
    }

    function parseBitboardsToString(uint64[12] memory bitboards) internal pure returns (string memory str){
        for (uint256 i = 0; i < bitboards.length; i++) {
            if (i != 0){
                str = str.append(string("|"));
            }
            for (uint256 j = 64; j > 0; j--){
                uint64 sqBoard = uint64(1 << (j-1));
                if (sqBoard & bitboards[i] != 0){
                    str = str.append(string("1"));
                }else {
                    str = str.append(string("0"));
                }
            }
        }
    }
}
