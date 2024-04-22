// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TicTacToe {

    uint8 constant O_SIGN = 1;
    uint8 constant X_SIGN = 2;

    // Enum representing the various states of a game. Each game init state when not created is equal Uninitialized state 
    // which is default default value (0) for the enum.
    enum GameState {
        Uninitialized,  // Default state for newly declared games, used to verify whether a game is initialized
        InviteSent,     // State indicates that an invite has been sent to another player - game is open
        InProgress,     // State during which the game is actively being played - game has started 
        Player1Win,     // Designated win state for player 1
        Player2Win,     // Designated win state for player 2
        Draw            // State indicating the game has ended in a draw
    }

    struct Game {
        address player1; // game initiator
        address player2; // invitee 
        uint8 player1Sign;
        uint8 player2Sign;
        uint256 board;  // Optimized board representation
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
    error InvalidCellValue();

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

    function openGame(address invitee) public returns(uint256) {
        if(invitee == msg.sender) {
            revert CanNotInviteYourself();
        }

        uint256 newGameId = gameIdCounter++;
        Game storage newGame = games[newGameId];
        newGame.player1 = msg.sender;
        newGame.player2 = invitee;
        newGame.board = 0;  // Initialize the board with 0
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
        if(getCell(game.board, x, y) != 0) {
            revert CellOccupied();
        }

        uint8 currentPlayerSign = (game.currentPlayer == game.player1) ? game.player1Sign : game.player2Sign;
        setCell(gameId, x, y, currentPlayerSign);

        if (checkWinner(games[gameId].board, currentPlayerSign)) {
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

    function getGameState(uint256 gameId) public view returns (GameState) {
        return games[gameId].state;
    }

    function getGameData(uint256 gameId) 
        public 
        view 
        returns (address, address, uint8, uint8, uint256, address, GameState) 
    {
        Game memory game = games[gameId];
        return (game.player1, game.player2, game.player1Sign, game.player2Sign, game.board, game.currentPlayer, game.state);
    }

    function checkWinner(uint256 board, uint8 playerSign) internal view returns (bool) {
        // Check rows and columns
        for (uint8 i = 0; i < 3; i++) {
            if (getCell(board, i, 0) == playerSign && getCell(board, i, 1) == playerSign && getCell(board, i, 2) == playerSign ||
                getCell(board, 0, i) == playerSign && getCell(board, 1, i) == playerSign && getCell(board, 2, i) == playerSign) {
                return true;
            }
        }
        // Check diagonals
        if (getCell(board, 0, 0) == playerSign && getCell(board, 1, 1) == playerSign && getCell(board, 2, 2) == playerSign ||
            getCell(board, 0, 2) == playerSign && getCell(board, 1, 1) == playerSign && getCell(board, 2, 0) == playerSign) {
            return true;
        }
        return false;
    }

    // all fields need to used and no one was selected as a winner
    function isDraw(uint256 board) internal view returns (bool) {
        for (uint8 i = 0; i < 3; i++) {
            for (uint8 j = 0; j < 3; j++) {
                if (getCell(board, i, j) == 0) {
                    return false;
                }
            }
        }
        return true;
    }


    /// Method sets the value of cell on the board represented as a bit array
    ///
    /// Explanation:
    /// The tic-tac-toe board is a 3x3 grid. We can think of it as a linear array of length 9 (since 3 rows * 3 columns = 9 cells).
    /// Each cell in this linearized version of the board can be indexed from 0 to 8.
    ///
    /// Each cell on the tic-tac-toe board can take on one of three values (0, 1, or 2), so we need 2 bits to represent the cell state.
    /// The position of the cell in the linear array is calculated by taking the index and multiplying it by 2 to allocate 2 bits per cell.
    /// Thus, (x * 3 + y) * 2 computes the starting bit position for the cell at coordinates (x, y)
    function setCell(uint256 gameId, uint8 x, uint8 y, uint8 value) internal {
        uint256 board = games[gameId].board;
        if(value > 2) {
            revert InvalidCellValue();
        }
        // Calculate the bit position for the specified cell
        uint shift = (x * 3 + y) * 2;
        // Create a bit mask (bit: 11) where only the bits for the specified cell are set (rest are 0)
        uint256 mask = uint256(3) << shift;  
        // Clear the given cell bits in board using mask and set new value (with the shit to get right position)
        board = (board & ~mask) | (uint256(value) << shift);
        games[gameId].board = board;
    }

    /// Method gets the value of cell on the board represented as a bit array
    function getCell(uint256 board, uint8 x, uint8 y) pure internal returns (uint8) {
        uint shift = (x * 3 + y) * 2;
        // Right-shift board` by bit position get the cell value at rightmost bits & mask with "11" 
        // to get the value 
        return uint8((board >> shift) & 3);
    }
}