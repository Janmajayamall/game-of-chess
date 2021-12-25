// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./../libraries/TestHelpers.t.sol";
import "./../helpers/TestToken.sol";
import "./../Game.sol";
import "ds-test/test.sol";


contract GameTest is Game, DSTest {

    function setUp() public {

        _newGame();

        uint moveV = TestHelpers.encodeMove(
            48, 
            40, 
            0,
            false,
            0,
            1,
            1
        );
    }

    function test_createNewGame() public {
        _newGame();
    }

    function test_pawnMove() public {
        // assertTrue(false);
        applyMove(68720527920);
    }

}