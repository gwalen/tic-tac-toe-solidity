// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm, TestBase} from "forge-std/Test.sol";
import {TicTacToe} from "../src/TicTacToe.sol";

contract TicTacToeTest is Test {

    address ALICE = makeAddr("ALICE");
    address BOB = makeAddr("BOB");
    
    function testStatusOfUninitializedGame() public {
        TicTacToe ticTacToe = new TicTacToe();
        uint256 randomGameId = 1234341234;

        TicTacToe.GameState state = ticTacToe.getGameState(randomGameId);
        assertEq(uint(state), uint(TicTacToe.GameState.Uninitialized));
    }

    function testStatusAfterInviteSent() public {
        TicTacToe ticTacToe = new TicTacToe();

        vm.prank(ALICE);
        uint256 gameId = ticTacToe.createGame(BOB);

        TicTacToe.GameState state = ticTacToe.getGameState(gameId);
        assertEq(uint(state), uint(TicTacToe.GameState.InviteSent));
    }

    function testCanNotInviteSelf() public {
        TicTacToe ticTacToe = new TicTacToe();

        vm.startPrank(ALICE);
        vm.expectRevert(abi.encodeWithSelector(TicTacToe.CanNotInviteYourself.selector));
        ticTacToe.createGame(ALICE);
        vm.stopPrank();
    }

    function testGameCreateAndStart() public {
        TicTacToe ticTacToe = new TicTacToe();

        vm.startPrank(ALICE);
        vm.expectEmit(false, false, false, true);
        emit TicTacToe.GameCreated(1, ALICE, BOB);
        uint256 gameId = ticTacToe.createGame(BOB);
        vm.stopPrank();

        vm.startPrank(BOB);
        vm.expectEmit(false, false, false, true);
        emit TicTacToe.GameStarted(1, ALICE, BOB);
        ticTacToe.joinGame(gameId);
        vm.stopPrank();

        TicTacToe.GameState state = ticTacToe.getGameState(gameId);
        assertEq(uint(state), uint(TicTacToe.GameState.InProgress));
    }

    function testMakeMove() public {
        TicTacToe ticTacToe = new TicTacToe();

        uint256 gameId = startGameAliceAndBob(ticTacToe);
        // player X starts the game - so he will be current player just after game starts
        ( , , , , , address playerX, ) = ticTacToe.getGameData(gameId);
        address playerO = playerX == ALICE ? BOB : ALICE;

        // assertEq(playerX, ALICE); // this case it will be Alice

        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 0, 0);

        vm.startPrank(playerX);
        vm.expectRevert(abi.encodeWithSelector(TicTacToe.NotYourTurn.selector));
        ticTacToe.makeMove(gameId, 0, 0);
        vm.stopPrank();

        vm.startPrank(playerO);
        vm.expectRevert(abi.encodeWithSelector(TicTacToe.CellOccupied.selector));
        ticTacToe.makeMove(gameId, 0, 0);
        vm.stopPrank();

        vm.prank(playerO);
        ticTacToe.makeMove(gameId, 0, 1);

        TicTacToe.GameState state = ticTacToe.getGameState(gameId);
        assertEq(uint(state), uint(TicTacToe.GameState.InProgress));
    }

    function testManyGamesOpenAndStarted() public {
        address JOE = makeAddr("JOE");
        address JIM = makeAddr("JIM");

        TicTacToe ticTacToe = new TicTacToe();

        vm.prank(ALICE);
        uint256 gameId1 = ticTacToe.createGame(BOB);

        vm.prank(ALICE);
        uint256 gameId2 = ticTacToe.createGame(JOE);

        // second game opened with Bob
        vm.prank(ALICE);
        uint256 gameId3 = ticTacToe.createGame(BOB);

        // bob also opened a game with Alice
        vm.prank(BOB);
        uint256 gameId4 = ticTacToe.createGame(ALICE);

        vm.prank(BOB);
        uint256 gameId5 = ticTacToe.createGame(JIM);

        // start some games

        vm.prank(BOB);
        ticTacToe.joinGame(gameId1);

        vm.prank(JOE);
        ticTacToe.joinGame(gameId2);

        vm.prank(ALICE);
        ticTacToe.joinGame(gameId4);

        vm.prank(JIM);
        ticTacToe.joinGame(gameId5);

        // 4 games stared 1 opened (invite sent)

        TicTacToe.GameState state1 = ticTacToe.getGameState(gameId1);
        TicTacToe.GameState state2 = ticTacToe.getGameState(gameId2);
        TicTacToe.GameState state3 = ticTacToe.getGameState(gameId3);
        TicTacToe.GameState state4 = ticTacToe.getGameState(gameId4);
        TicTacToe.GameState state5 = ticTacToe.getGameState(gameId5);

        assertEq(uint(state1), uint(TicTacToe.GameState.InProgress));
        assertEq(uint(state2), uint(TicTacToe.GameState.InProgress));
        assertEq(uint(state3), uint(TicTacToe.GameState.InviteSent));
        assertEq(uint(state4), uint(TicTacToe.GameState.InProgress));
        assertEq(uint(state5), uint(TicTacToe.GameState.InProgress));
    }

    /**
     * ```
         X| X | X
        ---------
         O| O |  
        ---------
          |   |  
        ```
     */
    function testGameWin() public {
        TicTacToe ticTacToe = new TicTacToe();
        uint256 gameId = startGameAliceAndBob(ticTacToe);
        // player X starts the game - so he will be current player just after game starts
        ( , , , , , address playerX, ) = ticTacToe.getGameData(gameId);
        address playerO = playerX == ALICE ? BOB : ALICE;

        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 0, 0); // X
        vm.prank(playerO);
        ticTacToe.makeMove(gameId, 1, 0); // O
        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 0, 1); // X
        vm.prank(playerO);
        ticTacToe.makeMove(gameId, 1, 1); // O
        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 0, 2); // X

        // Check the game state
        TicTacToe.GameState state = ticTacToe.getGameState(gameId);
        assertEq(uint(state), uint(TicTacToe.GameState.Player1Win));
        assertEq(playerX, ALICE);


        // try to make a move after game is over
        vm.startPrank(playerO);
        vm.expectRevert(abi.encodeWithSelector(TicTacToe.GameNotInProgress.selector));
        ticTacToe.makeMove(gameId, 2, 2);
        vm.stopPrank();
    }

    /**
     * ```
        O | X | O
        ---------
        O | X | X
        ---------
        X | O | X
        ```
     */
    function testGameDraw() public {
        TicTacToe ticTacToe = new TicTacToe();
        uint256 gameId = startGameAliceAndBob(ticTacToe);
        // player X starts the game - so he will be current player just after game starts
        ( , , , , , address playerX, ) = ticTacToe.getGameData(gameId);
        address playerO = playerX == ALICE ? BOB : ALICE;

        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 2, 0); // X

        vm.prank(playerO);
        ticTacToe.makeMove(gameId, 0, 0); // O

        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 1, 1); // X

        vm.prank(playerO);
        ticTacToe.makeMove(gameId, 0, 2); // O

        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 0, 1); // X

        vm.prank(playerO);
        ticTacToe.makeMove(gameId, 1, 0); // O

        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 1, 2); // X

        vm.prank(playerO);
        ticTacToe.makeMove(gameId, 2, 1); // O

        vm.prank(playerX);
        ticTacToe.makeMove(gameId, 2, 2); // X

        // Check the game state
        TicTacToe.GameState state = ticTacToe.getGameState(gameId);
        assertEq(uint(state), uint(TicTacToe.GameState.Draw));
    }


    function startGameAliceAndBob(TicTacToe game) internal returns(uint256) {
        vm.prank(ALICE);
        uint256 gameId = game.createGame(BOB);

        vm.prank(BOB);
        game.joinGame(gameId);

        return gameId;
    }



}
