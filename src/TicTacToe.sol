// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TicTacToe {

    uint8 constant O_SIGN = 1;
    uint8 constant X_SIGN = 2;

    enum GameState { Uninitialized, InviteSent, InProgress, Player1Win, Player2Win, Draw }

    struct Game {
        address player1;  // game initiator
        address player2;  // invitee
        uint8 player1Sign;
        uint8 player2Sign;
        uint8[3][3] board;  // TODO: optimize
        address currentPlayer;
        GameState state;
    }

    mapping(uint256 => Game) public games;
    uint256 private gameIdCounter = 1;

    event GameCreated(uint256 gameId, address creator, address invitee);
    event GameStarted(uint256 gameId, address player1, address player2);
    event MoveMade(uint256 gameId, address player, uint8 x, uint8 y);
    event GameEnded(uint256 gameId, GameState result);

    error InvalidPosition();
    error NotAParticipant();
    error GameNotInProgress();
    error NotYourTurn();
    error CellOccupied();
    error NoInvitationFoundOrWrongGameId();
    error CanNotInviteYourself();

    modifier isValidPosition(uint8 x, uint8 y) {
        if (x >= 3 || y >= 3) {
            revert InvalidPosition();
        }
        _;
    }

    modifier isPlayer(uint256 gameId, address player) {
        if(games[gameId].player1 != player && games[gameId].player2 != player) {
            revert NotAParticipant();
        }
        _;
    }

    function createGame(address invitee) public returns(uint256) {
        if(invitee == msg.sender) {
            revert CanNotInviteYourself();
        }

        uint256 newGameId = gameIdCounter++;
        Game storage newGame = games[newGameId];
        newGame.player1 = msg.sender;
        newGame.player2 = invitee;
        newGame.state = GameState.InviteSent;

        emit GameCreated(newGameId, msg.sender, invitee);
        return newGameId;
    }

    function joinGame(uint256 gameId) public {
        if (games[gameId].state != GameState.InviteSent) {
            revert NoInvitationFoundOrWrongGameId();
        }
        if (msg.sender != games[gameId].player2) {
            revert NotAParticipant();
        }

        Game storage game = games[gameId];
        game.state = GameState.InProgress;
        // Determine roles and set first move
        bytes32 hash = keccak256(abi.encodePacked(game.player1, game.player2));
        uint8 firstBit = uint8(hash[0]) & 0x01;
        if (firstBit == 0) {
            game.player1Sign = O_SIGN;
            game.player2Sign = X_SIGN;
            game.currentPlayer = game.player2; // X has first move
        } else {
            game.player1Sign = X_SIGN;
            game.player2Sign = O_SIGN;
            game.currentPlayer = game.player1; // X has first move
        
        } 

        emit GameStarted(gameId, game.player1, game.player2);
    }

    function makeMove(uint256 gameId, uint8 x, uint8 y) public isValidPosition(x, y) isPlayer(gameId, msg.sender) {
        Game storage game = games[gameId];
        if (game.state != GameState.InProgress) {
            revert GameNotInProgress();
        }
        if (game.currentPlayer != msg.sender) {
            revert NotYourTurn();
        }
        if(game.board[x][y] != 0) {
            revert CellOccupied();
        }

        uint8 currentPlayerSign = (game.currentPlayer == game.player1) ? game.player1Sign : game.player2Sign;
        game.board[x][y] = currentPlayerSign;

        if (checkWinner(gameId, currentPlayerSign)) {
            game.state = currentPlayerSign == game.player1Sign ? GameState.Player1Win : GameState.Player2Win;
            emit GameEnded(gameId, game.state);
        } else if (isDraw(game.board)) {
            game.state = GameState.Draw;
            emit GameEnded(gameId, game.state);
        } else {
            game.currentPlayer = (game.currentPlayer == game.player1) ? game.player2 : game.player1;
        }

        emit MoveMade(gameId, msg.sender, x, y);
    }

    function getGameStatus(uint256 gameId) public view returns (GameState) {
        return games[gameId].state;
    }

    function checkWinner(uint256 gameId, uint8 playerSign) internal view returns (bool) {
        uint8[3][3] memory board = games[gameId].board;
        for (uint i = 0; i < 3; i++) {
            if (board[i][0] == playerSign && board[i][1] == playerSign && board[i][2] == playerSign || 
                board[0][i] == playerSign && board[1][i] == playerSign && board[2][i] == playerSign) {
                return true;
            }
        }
        if (board[0][0] == playerSign && board[1][1] == playerSign && board[2][2] == playerSign ||
            board[0][2] == playerSign && board[1][1] == playerSign && board[2][0] == playerSign) {
            return true;
        }
        return false;
    }

    // all fields need to used and no one was selected as a winner
    function isDraw(uint8[3][3] memory board) internal pure returns (bool) {
        for (uint8 i = 0; i < 3; i++) {
            for (uint8 j = 0; j < 3; j++) {
                if (board[i][j] == 0) {
                    return false;
                }
            }
        }
        return true;
    }
}