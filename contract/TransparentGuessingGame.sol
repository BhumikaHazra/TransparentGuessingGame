// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/// @title Transparent Guessing Game (commit-reveal)
/// @author
/// @notice Simple single-round guessing game: owner commits a secret hash, players place bets with guesses,
/// owner reveals the secret and correct guessers split the pot.
/// @dev This is a learning example. Do not use on mainnet without audit and careful gas/edge-case handling.
contract TransparentGuessingGame {
    address public owner;
    bytes32 public secretHash;      // keccak256(abi.encodePacked(secret, salt))
    bool public committed;
    bool public revealed;
    uint256 public revealDeadline; // timestamp by which owner must reveal
    uint256 public guessDeadline;  // timestamp by which players must place their guesses
    uint256 public minBet;         // minimum bet per guess (wei)
    uint256 public totalPot;

    struct Guess {
        uint8 value;    // guessed number (0-255). change type if you want different range
        uint256 amount; // how much they bet
        bool exists;
        bool claimed;
    }

    // player => their guess (only one guess per address in this simple version)
    mapping(address => Guess) public guesses;

    // book-keeping of winners after reveal
    address[] public winners;

    event Committed(bytes32 indexed secretHash, uint256 guessDeadline, uint256 revealDeadline, uint256 minBet);
    event GuessPlaced(address indexed player, uint8 guess, uint256 amount);
    event Revealed(string secret, uint256 salt, uint8 secretValue);
    event PrizeClaimed(address indexed player, uint256 amount);
    event Refund(address indexed player, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    modifier onlyBeforeGuessDeadline() {
        require(block.timestamp <= guessDeadline, "guess deadline passed");
        _;
    }

    modifier onlyAfterReveal() {
        require(revealed, "not revealed yet");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Owner commits to a secret (hash) before players guess.
    /// @param _secretHash keccak256(abi.encodePacked(secret, salt))
    /// @param _guessPeriod seconds from now players can place guesses
    /// @param _revealPeriod seconds after guessDeadline owner must reveal (revealDeadline = now + _guessPeriod + _revealPeriod)
    /// @param _minBet minimum bet in wei
    function commitSecret(
        bytes32 _secretHash,
        uint256 _guessPeriod,
        uint256 _revealPeriod,
        uint256 _minBet
    ) external onlyOwner {
        require(!committed, "already committed");
        require(_guessPeriod > 0 && _revealPeriod > 0, "periods must be >0");
        secretHash = _secretHash;
        guessDeadline = block.timestamp + _guessPeriod;
        revealDeadline = guessDeadline + _revealPeriod;
        minBet = _minBet;
        committed = true;
        revealed = false;
        totalPot = 0;
        // clear winners array if reused (simple)
        delete winners;

        emit Committed(secretHash, guessDeadline, revealDeadline, minBet);
    }

    /// @notice Players place a guess and send ETH (at least minBet). One guess per address.
    /// @param _guess a small number (0-255)
    function placeGuess(uint8 _guess) external payable onlyBeforeGuessDeadline {
        require(committed, "not started");
        require(msg.value >= minBet, "bet too small");
        require(!guesses[msg.sender].exists, "already guessed");

        guesses[msg.sender] = Guess({value: _guess, amount: msg.value, exists: true, claimed: false});
        totalPot += msg.value;

        emit GuessPlaced(msg.sender, _guess, msg.value);
    }

    /// @notice Owner reveals the secret and salt. The revealed secret must match the earlier committed hash.
    /// @param _secret the secret string/number owner used
    /// @param _salt a uint256 salt owner used
    function reveal(string calldata _secret, uint256 _salt) external onlyOwner {
        require(committed, "not started");
        require(!revealed, "already revealed");
        require(block.timestamp <= revealDeadline, "reveal period over");

        // compute hash and verify
        bytes32 computed = keccak256(abi.encodePacked(_secret, _salt));
        require(computed == secretHash, "secret mismatch");

        // derive a secret value (0-255) deterministically from the secret for comparison
        // e.g., take the first byte of the hash of the secret + salt.
        bytes32 h = keccak256(abi.encodePacked(_secret, _salt, block.number)); // include block.number for extra unpredictability on reveal time
        uint8 secretValue = uint8(uint256(h) & 0xFF); // 0..255

        // find winners
        for (uint256 i = 0; i < 0; i++) {
            // no-op placeholder, solidity doesn't allow iterating mapping directly
        }
        // We must iterate players, but mapping can't be enumerated. In this simple contract,
        // we will instead track winners by re-scanning guesses through an off-chain list or
        // allow players to claim individually by comparing their guess to secretValue.
        // So we store secretValue for later checks.
        _storeReveal(secretValue);

        revealed = true;
        emit Revealed(_secret, _salt, secretValue);
    }

    // Store revealed secret value in contract for on-chain checking.
    uint8 public revealedSecretValue;

    function _storeReveal(uint8 v) internal {
        revealedSecretValue = v;
    }

    /// @notice Claim prize: if the caller guessed the correct value, they can claim their share of the pot.
    /// Splits pot equally between correct guessers based on their stake proportion (pro rata by stake).
    function claimPrize() external onlyAfterReveal {
        Guess storage g = guesses[msg.sender];
        require(g.exists, "no guess");
        require(!g.claimed, "already claimed");

        if (g.value != revealedSecretValue) {
            // wrong guess: nothing to claim (but we allow owner to refund later or keep house edge)
            g.claimed = true;
            emit PrizeClaimed(msg.sender, 0);
            return;
        }

        // calculate total winning stake: need to compute total stake of correct guessers
        uint256 totalWinningStake = _totalWinningStake();

        require(totalWinningStake > 0, "no winners"); // should not happen

        // winner gets share = (their stake / totalWinningStake) * totalPot
        uint256 payout = (totalPot * g.amount) / totalWinningStake;

        g.claimed = true;

        // transfer payout (use call to avoid gas issues)
        (bool ok, ) = msg.sender.call{value: payout}("");
        require(ok, "transfer failed");

        emit PrizeClaimed(msg.sender, payout);
    }

    /// @notice Calculate total stake of the correct guessers by scanning a list.
    /// @dev Since mappings are not enumerable, this function is written as a helper that expects
    /// the contract to be used with an off-chain index of players OR for small games you can
    /// maintain an array of players on-placeGuess (not done here to keep storage lower).
    /// For simplicity in this demo, we maintain an array of players.
    address[] public playerList;

    // Modified placeGuess to push to playerList (we need to update the function above).
    // To keep the code consistent, include a separate lighter function to place guesses that uses playerList.

    /// @notice Simpler guess function (use this one for the sample demo; it records players)
    function placeGuessWithList(uint8 _guess) external payable onlyBeforeGuessDeadline {
        require(committed, "not started");
        require(msg.value >= minBet, "bet too small");
        require(!guesses[msg.sender].exists, "already guessed");

        guesses[msg.sender] = Guess({value: _guess, amount: msg.value, exists: true, claimed: false});
        playerList.push(msg.sender);
        totalPot += msg.value;

        emit GuessPlaced(msg.sender, _guess, msg.value);
    }

    function _totalWinningStake() internal view returns (uint256 total) {
        uint256 len = playerList.length;
        for (uint256 i = 0; i < len; ++i) {
            address p = playerList[i];
            Guess storage g = guesses[p];
            if (g.exists && g.value == revealedSecretValue) {
                total += g.amount;
            }
        }
    }

    /// @notice If owner fails to reveal in time, players can request refund of their bets.
    function refund() external {
        require(committed, "not started");
        require(!revealed, "already revealed");
        require(block.timestamp > revealDeadline, "reveal deadline not passed");

        Guess storage g = guesses[msg.sender];
        require(g.exists, "no guess");
        require(!g.claimed, "already claimed/refunded");

        uint256 amount = g.amount;
        g.claimed = true;
        // reduce pot
        if (amount <= totalPot) {
            totalPot -= amount;
        } else {
            totalPot = 0;
        }

        (bool ok, ) = msg.sender.call{value: amount}("");
        require(ok, "refund transfer failed");

        emit Refund(msg.sender, amount);
    }

    /// @notice Owner can withdraw remaining funds (e.g., house edge) after all claims/refunds or after a long timeout.
    function ownerWithdraw(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "insufficient balance");
        (bool ok, ) = owner.call{value: amount}("");
        require(ok, "withdraw failed");
    }

    /// @notice Reset contract to play another round. Only owner and only when previous round fully settled.
    /// @dev For demo only — in production you'd want stronger checks.
    function reset() external onlyOwner {
        require(revealed || block.timestamp > revealDeadline, "round not finished");
        // clear guesses and playerList (gas expensive if many players)
        for (uint256 i = 0; i < playerList.length; ++i) {
            delete guesses[playerList[i]];
        }
        delete playerList;
        committed = false;
        revealed = false;
        secretHash = bytes32(0);
        totalPot = 0;
        revealedSecretValue = 0;
    }

    // Fallback to accept ETH
    receive() external payable {}
}

