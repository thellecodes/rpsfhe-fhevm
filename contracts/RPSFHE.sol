// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";

contract RPSFHE is SepoliaZamaFHEVMConfig {
    enum GameState { Created, Joined, Finished }

    struct Game {
        address player1;
        address player2;
        euint8 move1; // Encrypted move
        euint8 move2; // Encrypted move
        GameState state;
        address winner;
        euint8 resultCode; // Encrypted result code: 0=Draw, 1=P1 wins, 2=P2 wins
    }

    mapping(uint256 => Game) public games;
    uint256 public gameCounter;

    event GameCreated(uint256 indexed gameId, address player1);
    event GameJoined(uint256 indexed gameId, address player2);
    event GameFinished(uint256 indexed gameId, address winner, euint8 encryptedResult);
    event SinglePlayerGameFinished(address player, euint8 encryptedResult);

    // --- Two-player game functions ---

    function createGame(euint8 encryptedMove) external {
        gameCounter++;
        games[gameCounter] = Game({
            player1: msg.sender,
            player2: address(0),
            move1: encryptedMove,
            move2: TFHE.asEuint8(0),
            state: GameState.Created,
            winner: address(0),
            resultCode: TFHE.asEuint8(0)
        });
        emit GameCreated(gameCounter, msg.sender);
    }

    function joinGame(uint256 gameId, euint8 encryptedMove) external {
        Game storage game = games[gameId];
        require(game.state == GameState.Created, "Game not joinable");
        require(msg.sender != game.player1, "Can't join your own game");

        game.player2 = msg.sender;
        game.move2 = encryptedMove;
        game.state = GameState.Joined;

        emit GameJoined(gameId, msg.sender);

        _determineWinner(gameId);
    }

   function _determineWinner(uint256 gameId) internal {
    Game storage game = games[gameId];
    euint8 p1 = game.move1;
    euint8 p2 = game.move2;

    // 0 = Rock, 1 = Paper, 2 = Scissors
    ebool draw = TFHE.eq(p1, p2);

    // Rock (0) beats Scissors (2)
    ebool cond1 = TFHE.cmux(
        TFHE.eq(p1, TFHE.asEuint8(0)),
        TFHE.eq(p2, TFHE.asEuint8(2)),
        TFHE.asEbool(false)
    );

    // Paper (1) beats Rock (0)
    ebool cond2 = TFHE.cmux(
        TFHE.eq(p1, TFHE.asEuint8(1)),
        TFHE.eq(p2, TFHE.asEuint8(0)),
        TFHE.asEbool(false)
    );

    // Scissors (2) beats Paper (1)
    ebool cond3 = TFHE.cmux(
        TFHE.eq(p1, TFHE.asEuint8(2)),
        TFHE.eq(p2, TFHE.asEuint8(1)),
        TFHE.asEbool(false)
    );

    // Combine all win conditions using cmux
    ebool temp = TFHE.cmux(cond2, TFHE.asEbool(true), cond3);
    ebool p1Wins = TFHE.cmux(cond1, TFHE.asEbool(true), temp);

    // Encode result: 0 = Draw, 1 = Player1 wins, 2 = Player2 wins
    euint8 resultCode = TFHE.cmux(
        draw,
        TFHE.asEuint8(0),
        TFHE.cmux(p1Wins, TFHE.asEuint8(1), TFHE.asEuint8(2))
    );

    game.state = GameState.Finished;
    game.resultCode = resultCode;
    game.winner = address(0); // winner kept confidential

    emit GameFinished(gameId, address(0), resultCode);
}


    function viewWinner(uint256 gameId) external view returns (address) {
        Game storage game = games[gameId];
        require(game.state == GameState.Finished, "Game not finished yet");
        return game.winner;
    }

    function viewResultCode(uint256 gameId) external view returns (euint8) {
        Game storage game = games[gameId];
        require(game.state == GameState.Finished, "Game not finished yet");
        return game.resultCode;
    }

    // --- Single-player game with on-chain randomness ---

    function singlePlayerGame(euint8 playerMove) external {
        // Generate pseudo-random uint8 (0,1,2) using block data and sender
        uint8 randomMove = uint8(
            uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp, msg.sender))) % 3
        );

        // Encrypt opponent move
        euint8 opponentMove = TFHE.asEuint8(randomMove);

        // Determine winner using encrypted logic
        ebool draw = TFHE.eq(playerMove, opponentMove);

        ebool p1Wins = TFHE.or_(
            TFHE.and_(TFHE.eq(playerMove, TFHE.asEuint8(0)), TFHE.eq(opponentMove, TFHE.asEuint8(2))), // Rock beats Scissors
            TFHE.or_(
                TFHE.and_(TFHE.eq(playerMove, TFHE.asEuint8(1)), TFHE.eq(opponentMove, TFHE.asEuint8(0))), // Paper beats Rock
                TFHE.and_(TFHE.eq(playerMove, TFHE.asEuint8(2)), TFHE.eq(opponentMove, TFHE.asEuint8(1)))  // Scissors beats Paper
            )
        );

        euint8 resultCode = TFHE.cmux(
            draw,
            TFHE.asEuint8(0),
            TFHE.cmux(p1Wins, TFHE.asEuint8(1), TFHE.asEuint8(2))
        );

        emit SinglePlayerGameFinished(msg.sender, resultCode);
    }
}
