// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./../tests/TestHelpers.t.sol";

contract GameTest is TestHelpers {

    function setUp() public {
        newGame();

        uint moveV = encodeMove(
            48, 
            40, 
            0,
            false,
            0,
            1,
            1
        );
        emit log_named_uint("Move Value: ", moveV);
    }

    function test_createNewGame() public {
        newGame();
    }

    function test_pawnMove() public {
        // assertTrue(false);
        applyMove(68720527920);
    }

}