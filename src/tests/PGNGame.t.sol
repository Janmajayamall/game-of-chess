// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./../libraries/TestHelpers.t.sol";
import "./../libraries/String.sol";
import "./../helpers/TestToken.sol";
import "./../Goc.sol";
import "ds-test/test.sol";


contract PGNGame is DSTest {
    using String for string;

    Goc goc;
    TestToken testToken;

    function setUp() public {
        testToken= new TestToken();
        goc = new Goc(address(testToken));
    }   

    /*
        Few game PGNs

        1. Aron Nimzowitsch vs Siegbert Tarrasch St. Petersburg (1914), (@ref - https://www.chessgames.com/perl/chessgame?gid=1102384)
        "1. d4 d5 2. Nf3 c5 3. c4 e6 4. e3 Nf6 5. Bd3 Nc6 6. O-O Bd6 7. b3 O-O 8. Bb2 b6 9. Nbd2 Bb7 10. Rc1 Qe7 11. cxd5 exd5 12. Nh4 g6 13. Nhf3 Rad8 14. dxc5 bxc5 15. Bb5 Ne4 16. Bxc6 Bxc6 17. Qc2 Nxd2 18. Nxd2 d4 19. exd4 Bxh2+ 20. Kxh2 Qh4+ 21. Kg1 Bxg2 22. f3 Rfe8 23. Ne4 Qh1+ 24. Kf2 Bxf1 25. d5 f5 26. Qc3 Qg2+ 27. Ke3 Rxe4+ 28. fxe4 f4+ 29. Kxf4 Rf8+ 30. Ke5 Qh2+ 31. Ke6 Re8+ 32. Kd7 Bb5 ";

        2. Adolf Anderssen vs Lionel Adalbert Bagration Felix Kieseritsky (The Immortal Game)
        "1. e4 e5 2. f4 exf4 3. Bc4 Qh4+ 4. Kf1 b5 5. Bxb5 Nf6 6. Nf3 Qh6 7. d3 Nh5 8. Nh4 Qg5 9. Nf5 c6 10. g4 Nf6 11. Rg1 cxb5 12. h4 Qg6 13. h5 Qg5 14. Qf3 Ng8 15. Bxf4 Qf6 16. Nc3 Bc5 17. Nd5 Qxb2 18. Bd6 Bxg1 19. e5 Qxa1+ 20. Ke2 Na6 21. Nxg7+ Kd8 22. Qf6+ Nxf6 23. Be7 "

     */

    function est_ChessGame() public {
        Goc _goc = goc;

        string memory pgnStr = "1. e4 e5 2. f4 exf4 3. Bc4 Qh4+ 4. Kf1 b5 5. Bxb5 Nf6 6. Nf3 Qh6 7. d3 Nh5 8. Nh4 Qg5 9. Nf5 c6 10. g4 Nf6 11. Rg1 cxb5 12. h4 Qg6 13. h5 Qg5 14. Qf3 Ng8 15. Bxf4 Qf6 16. Nc3 Bc5 17. Nd5 Qxb2 18. Bd6 Bxg1 19. e5 Qxa1+ 20. Ke2 Na6 21. Nxg7+ Kd8 22. Qf6+ Nxf6 23. Be7 ";

        uint16 gameId = 1;

        _goc.newGame();

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
            moveValue = testHelpers.parsePGNToMoveValue(
                whiteM,
                0,
                _goc.getGameState(gameId).bitboards,
                moveCount,
                gameId
            );
            debugStr = debugStr.append(testHelpers.formatMoveMetadataToString(moveValue, _goc.getGameState(gameId).bitboards));
            _goc.applyMove(moveValue);
            debugStr = debugStr.append(testHelpers.formatBoardToString(_goc.getGameState(gameId).bitboards));

            index += 1; // skip space

            // game might end after white move
            if (index < pgnBytes.length){
                // collect black move 
                bytes memory blackM;
                while (pgnBytes[index] != bytes1(" ")){
                    blackM = bytes.concat(blackM, pgnBytes[index]);
                    index += 1;
                }
                // emit log_named_string("PGN Black value: ", string(blackM));
                debugStr = debugStr.append(string("\n PGN Black value: ").append(string(blackM)));
                moveCount += 1;
                moveValue = testHelpers.parsePGNToMoveValue(
                    blackM,
                    1,
                    testHelpers.gamesState[gameId].bitboards,
                    moveCount,
                    gameId
                );
                debugStr = debugStr.append(testHelpers.formatMoveMetadataToString(moveValue, _goc.getGameState(gameId).bitboards));
                testHelpers.applyMove(moveValue);
                debugStr = debugStr.append(testHelpers.formatBoardToString(_goc.getGameState(gameId).bitboards));
                
                index += 1;

                debugStr = debugStr.append("\n ********** MOVE SET ENDS ********** \n");
            }
        }
        emit log_string(debugStr);
        assertTrue(false);
    }

}