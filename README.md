# RPSFHE - Fully Homomorphic Encrypted Rock Paper Scissors Game

## Overview

This contract implements a Rock-Paper-Scissors (RPS) game using Fully Homomorphic Encryption (FHE) powered by Zama’s TFHE for on-chain encrypted move comparison.

Players can:
- Play a 2-player encrypted game securely.
- Play against a pseudo-random AI for single-player mode.

---

## Repository Setup

```bash
# Clone the repository
git clone git@github.com:thellecodes/rpsfhe-fhevm.git
cd rpsfhe-fhevm

# Set up FHEVM (make sure you're on Sepolia for deploying)
```

---

## Smart Contract Functions

### 1. `createGame(euint8 encryptedMove)`

Creates a new game with Player 1’s encrypted move.

- **Params:** `encryptedMove` (euint8)
- **Emits:** `GameCreated(gameId, player1)`

---

### 2. `joinGame(uint256 gameId, euint8 encryptedMove)`

Joins an existing game as Player 2 and sets their encrypted move.

- **Params:** `gameId`, `encryptedMove`
- **Emits:** `GameJoined(gameId, player2)`, `GameFinished(gameId, winner, resultCode)`

---

### 3. `viewWinner(uint256 gameId)`

Returns the winner address (always address(0) for privacy).

- **Params:** `gameId`
- **Returns:** `address`

---

### 4. `viewResultCode(uint256 gameId)`

Returns the encrypted result code.

- **Params:** `gameId`
- **Returns:** `euint8 (0=Draw, 1=Player1 wins, 2=Player2 wins)`

---

### 5. `singlePlayerGame(euint8 playerMove)`

Play a single-player match against a pseudo-random move.

- **Params:** `playerMove` (euint8)
- **Emits:** `SinglePlayerGameFinished(player, resultCode)`

---

## Internal Function

### `_determineWinner(uint256 gameId)`

Determines the winner based on encrypted moves using TFHE's `cmux` logic.

---

## Frontend Developer Reference

To interact with the contract:

- Call `createGame` with the encrypted move using TFHE SDK.
- Call `joinGame` with the game ID and encrypted move.
- Wait for the `GameFinished` event and read the encrypted `resultCode`.
- Call `viewResultCode(gameId)` and decrypt off-chain to find out the result.

All sensitive logic is computed homomorphically and returned encrypted for privacy.

---

## Developer Report

### What was done

- Fully homomorphic RPS logic with 2-player and single-player support.
- Secure on-chain comparison using `cmux`, `eq`, and `asEuint8/asEbool`.
- Maintained on-chain privacy for moves and outcomes.

### What went well

- Successful use of `TFHE.cmux` to handle conditional encrypted logic.
- Functional encryption-based game mechanics without revealing player intent.

### What didn’t go so well

- Complexity in composing encrypted logical expressions required careful design.
- Limited ability to fully simulate without frontend encryption tool integration.

### What I would do with more time

- Add full end-to-end testing with a frontend using the Zama SDK.
- Add support for wagering or token-based rewards.

---
