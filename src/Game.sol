// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
// import "ds-test/test.sol";
import "./interfaces/IGocDataTypes.sol";
import "./libraries/GameHelpers.sol";

contract Game is IGocDataTypes {
    // gameId => game's state
    mapping(uint16 => GameState) gamesState;
    
    // game index
    uint16 public gameIndex;

    function getGameState(uint16 _gameIndex) external view returns (GameState memory){
        return gamesState[_gameIndex];
    }

    function applyMove(uint256 _moveValue) internal {
        uint16 _gameId = GameHelpers.decodeGameIdFromMoveValue(_moveValue);
        GameState memory gameState = gamesState[_gameId];
        MoveMetadata memory move = GameHelpers.decodeMoveMetadataFromMoveValue(_moveValue, gameState.bitboards);

        // check whether move is valid
        require(GameHelpers.isMoveValid(gameState, move), "Invalid move");
        
        // check game over
        if (move.targetPiece == Piece.K){
            // black won
            gameState.winner = 1;
            gameState.state = 2;
        }else if (move.targetPiece == Piece.k){
            // white won
            gameState.winner = 0;
            gameState.state = 2;
        }
        // game not over
        else {
            // increment halfmove clock
            gameState.halfMoveCount += 1;

            // update source piece pos to target sq
            gameState.bitboards[uint(move.sourcePiece)] = (gameState.bitboards[uint(move.sourcePiece)] | uint64(1 << move.targetSq)) & ~(uint64(1 << move.sourceSq));
           
            // remove target piece from target sq
            if (move.targetPiece != Piece.uk ){
                gameState.bitboards[uint(move.targetPiece)] &= ~uint64(1 << move.targetSq);
            }
            
            // update half move count
            if (move.targetPiece != Piece.uk || move.sourcePiece == Piece.p || move.sourcePiece == Piece.P) {
                gameState.halfMoveCount = 0;
            }

            // update rook position, since position update of king has been taken care of above
            if (move.moveFlag == MoveFlag.Castle){
                if (move.targetSq == 62){
                    // update rook on 63 to 61
                    gameState.bitboards[uint(Piece.R)] = (gameState.bitboards[uint(Piece.R)] | uint64(1) << 61) & ~(uint64(1) << 63);
                }else if (move.targetSq == 58){
                    // update rook on 56 to 59
                    gameState.bitboards[uint(Piece.R)] = (gameState.bitboards[uint(Piece.R)] | uint64(1) << 59) & ~(uint64(1) << 56);
                }else if (move.targetSq == 6){
                    // update rook on 7 to 5
                    gameState.bitboards[uint(Piece.r)] = (gameState.bitboards[uint(Piece.r)] | uint64(1) << 5) & ~(uint64(1) << 7);
                }else if (move.targetSq == 2){
                    // update rook on 0 to 3
                    gameState.bitboards[uint(Piece.r)] = (gameState.bitboards[uint(Piece.r)] | uint64(1) << 3) & ~(uint64(1) << 0);
                }
            }

            // update pawn promotion
            if (move.moveFlag == MoveFlag.PawnPromotion){
                // add promoted piece at target sq
                gameState.bitboards[uint(move.promotedToPiece)] |= uint64(1 << move.targetSq);
                // remove pawn from target sq
                gameState.bitboards[uint(move.sourcePiece)] &= ~uint64(1 << move.targetSq);
            }
            
            // update enpassant
            if ((move.sourcePiece == Piece.p || move.sourcePiece == Piece.P) && move.moveBySq == 16){
                gameState.enpassantSq = uint64(move.moveLeftShift == true ? move.sourceSq + 8 : move.sourceSq - 8);
            }else{
                gameState.enpassantSq = 0; // Note 0 is an illegal enpassant square
            }
            
            // update castling rights
            if (move.sourcePiece == Piece.K){
                gameState.wkC = false;
                gameState.wqC = false;
            }
            if (move.sourcePiece == Piece.R){
                if (move.sourceSq == 56){
                    gameState.wqC = false;
                }else if (move.sourceSq == 63){
                    gameState.wkC = false;
                }
            }
            if (move.sourcePiece == Piece.k){
                gameState.bkC = false;
                gameState.bqC = false;
            }
            if (move.sourcePiece == Piece.r){
                if (move.sourceSq == 0){
                    gameState.bqC = false;
                }else if (move.sourceSq == 7){
                    gameState.bkC = false;
                }
            }

            // switch playing side
            if (gameState.side == 0){
                gameState.side = 1;
            }else{
                gameState.side = 0;
            }

            // increase move count
            gameState.moveCount += 1;
        }

        // update game's state
        gamesState[_gameId] = gameState;
    }

    function _oddCaseDeclareOutcome(uint256 outcome, uint256 _moveValue) internal  {
        uint16 _gameId = GameHelpers.decodeGameIdFromMoveValue(_moveValue);
        GameState memory _gameState = gamesState[_gameId];
        require(_gameState.state == 1, "Invalid State");
        require(outcome < 3, "Invalid outcome");
        _gameState.winner = uint8(outcome);
        gamesState[_gameId] = _gameState;
    }

    function _newGame() internal returns (uint16 newGameIndex) {
        // initialise game state
        GameState memory _gameState;
        _gameState.state = 1;
        _gameState.winner = 2;
        _gameState.bkC = true;
        _gameState.bqC = true;
        _gameState.wkC = true;
        _gameState.wqC = true;

        
        // initial bitbaords
        _gameState.bitboards = [
            // initial black pos
            65280,
            66,
            36,
            129,
            8,
            16,
            // initial white pos
            71776119061217280,
            4755801206503243776,
            2594073385365405696,
            9295429630892703744,
            576460752303423488,
            1152921504606846976
        ];

        // add game
        newGameIndex = gameIndex + 1;
        gamesState[newGameIndex] = _gameState;

        // update index
        gameIndex = newGameIndex;
    }
}

































































































/**
    Move bits
   0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0011 1111 source sq
   0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 1111 1100 0000 target sq
   0000 0000 0000 0000 0000 0000 0000 0000 0000 1111 0000 0000 0000 promoted piece
   0000 0000 0000 0000 0000 0000 0000 0000 0001 0000 0000 0000 0000 castle flag
   0000 0000 0000 0000 0000 0000 0000 0000 0010 0000 0000 0000 0000 side
   0000 0000 0000 0000 1111 1111 1111 1111 0000 0000 0000 0000 0000 game id
   1111 1111 1111 1111 0000 0000 0000 0000 0000 0000 0000 0000 0000 move count
                             gameid    // 
                             moveCount // 16 
    52 bits. 
    uint56 since 52 isn't present; probably can use extra bits to crunch in somme extra info
 */

/**

    Block pieces 

    p ()
    0 0 0 0 0 0 0 0 
    1 1 1 1 1 1 1 1 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 

    n
    0 1 0 0 0 0 1 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0

    r
    1 0 0 0 0 0 0 1
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 

    q
    0 0 0 1 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0

    k
    0 0 0 0 1 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 

    White pieces 
    
    P
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    1 1 1 1 1 1 1 1 
    0 0 0 0 0 0 0 0 

    N
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 1 0 0 0 0 1 0

    R
    0 0 0 0 0 0 0 0
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    1 0 0 0 0 0 0 1

    Q
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 1 0 0 0 0

    K
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 0 0 0 0 
    0 0 0 0 1 0 0 0 


 */
    