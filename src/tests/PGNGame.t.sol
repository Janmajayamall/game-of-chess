// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./TestHelpers.t.sol";
import "./../libraries/String.sol";

contract PGNGame is TestHelpers {
    using String for string;

    function test_ChessGame() public {
        string memory pgnStr = "1. d4 d5 2. Nf3 c5 3. c4 e6 4. e3 Nf6 5. Bd3 Nc6 6. O-O Bd6 7. b3 O-O 8. Bb2 b6 9. Nbd2 Bb7 10. Rc1 Qe7 11. cxd5 exd5 12. Nh4 g6 13. Nhf3 Rad8 14. dxc5 bxc5 15. Bb5 Ne4 16. Bxc6 Bxc6 17. Qc2 Nxd2 18. Nxd2 d4 19. exd4 Bxh2+ 20. Kxh2 Qh4+ 21. Kg1 Bxg2 22. f3 Rfe8 23. Ne4 Qh1+ 24. Kf2 Bxf1 25. d5 f5 26. Qc3 Qg2+ 27. Ke3 Rxe4+ 28. fxe4 f4+ 29. Kxf4 Rf8+ 30. Ke5 Qh2+ 31. Ke6 Re8+ 32. Kd7 Bb5 ";

        uint16 gameId = 1;

        newGame();

        // run
        bytes memory pgnBytes = bytes(pgnStr);
        uint index = 0;
        uint16 moveCount = 0;
        uint moveValue;

        string memory debugStr = "";

        while (index < pgnBytes.length){
            while(pgnBytes[index] != bytes1(".")){
                index += 1;
            }

            index += 2; // skip space

            // new move
            debugStr = debugStr.append("\n ********** NEW MOVE SET ********** \n");

            // white move
            bytes memory whiteM;
            while (pgnBytes[index] != bytes1(" ")){
                whiteM = bytes.concat(whiteM, pgnBytes[index]);
                index += 1;
            }
            // emit log_named_string("PGN White value: ", string(whiteM));
            debugStr = debugStr.append(string("\n PGN White value: ").append(string(whiteM)));
            moveCount += 1;
            moveValue = parsePGNToMoveValue(
                whiteM,
                0,
                gamesState[gameId].bitboards,
                moveCount,
                gameId
            );
            debugStr = debugStr.append(formatMoveMetadataToString(moveValue));
            applyMove(moveValue);
            debugStr = debugStr.append(formatBoardToString(1));

            index += 1; // skip space

            // collect black move 
            bytes memory blackM;
            while (pgnBytes[index] != bytes1(" ")){
                blackM = bytes.concat(blackM, pgnBytes[index]);
                index += 1;
            }
            // emit log_named_string("PGN Black value: ", string(blackM));
            debugStr = debugStr.append(string("\n PGN Black value: ").append(string(blackM)));
            moveCount += 1;
            moveValue = parsePGNToMoveValue(
                blackM,
                1,
                gamesState[gameId].bitboards,
                moveCount,
                gameId
            );
            debugStr = debugStr.append(formatMoveMetadataToString(moveValue));
            applyMove(moveValue);
            debugStr = debugStr.append(formatBoardToString(1));
            
            index += 1;

            debugStr = debugStr.append("\n ********** MOVE SET ENDS ********** \n");
        }
        emit log_string(debugStr);
        assertTrue(false);
    }

}