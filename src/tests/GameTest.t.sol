// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../libraries/TestHelpers.t.sol";
import "./../libraries/GameHelpers.sol";
import "./../libraries/GameParsers.sol";
import "./../helpers/TestToken.sol";
import "./../Game.sol";
import "ds-test/test.sol";


contract GameTest is Game, DSTest {

    function setUp() public {

        _newGame();

        // uint moveV = TestHelpers.encodeMove(
        //     48, 
        //     40, 
        //     0,
        //     false,
        //     0,
        //     1,
        //     1
        // );
    }

    // function test_createNewGame() public {
    //     _newGame();
    // }

    // function test_pawnMove() public {
    //     emit log_named_string("JKJK ", GameParsers.parseGameStateToFenString(gamesState[1]));
    //     // emit log_named_string("JKJK ", GameParsers.parseBitboardsToString(gamesState[1].bitboards));

    //     // applyMove(68720527920);

    //     // emit log_named_string("JKJK 1", GameParsers.parseBitboardsToString(gamesState[1].bitboards));
        
    //     // assertTrue(false);
    // }


    function test_encodeMove() public {
        uint16 gameId = 1;
        uint moveValue = TestHelpers.encodeMove(
            49, 
            41, 
            0,
            false,
            0,
            gameId,
            1
        );
        emit log_named_uint("moveValue", moveValue);
        // uint moveValue = 68720527920;
        // GameHelpers.decodeGameIdFromMoveValue(moveValue);
        // IGocDataTypes.GameState memory state = gamesState[gameId];
        // bool isValid = GameHelpers.isMoveValid(state, GameHelpers.decodeMoveMetadataFromMoveValue(moveValue, state.bitboards));
        assertTrue(false);
    }
}