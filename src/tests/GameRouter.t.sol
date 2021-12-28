// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../libraries/TestHelpers.t.sol";
import "./../libraries/GameHelpers.sol";
import "./../libraries/GameParsers.sol";
import "./../helpers/TestToken.sol";
import "./../Goc.sol";
import "./../GocRouter.sol";
import "ds-test/test.sol";


contract GameRouterTest is DSTest {

    GocRouter gocRouter;
    Goc goc;
    TestToken testToken;

    function setUp() public {
        testToken = new TestToken();
        goc = new Goc(address(testToken));
        gocRouter = new GocRouter(address(goc));

        goc.newGame();
    }

    function test_moveValid() public {
        gocRouter.isMoveValid(68720527920);
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


    // function test_encodeMove() public {
    //     uint16 gameId = 1;
    //     // uint moveValue = TestHelpers.encodeMove(
    //     //     48, 
    //     //     40, 
    //     //     0,
    //     //     false,
    //     //     0,
    //     //     gameId,
    //     //     1
    //     // );
    //     uint moveValue = 68720527920;
    //     GameHelpers.decodeGameIdFromMoveValue(moveValue);
    //     IGocDataTypes.GameState memory state = gamesState[gameId];
    //     bool isValid = GameHelpers.isMoveValid(state, GameHelpers.decodeMoveMetadataFromMoveValue(moveValue, state.bitboards));
    //     require(isValid);
    // }
}