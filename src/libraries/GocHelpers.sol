pragma solidity ^0.8.0;

import "./../libraries/String.sol";
import "./../libraries/Uint.sol";

library GocHelpers {
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

}