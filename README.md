# 🎯 Transparent Guessing Game using Smart Randomness

Welcome to the **Transparent Guessing Game**, a beginner-friendly Solidity smart contract project built to demonstrate how **commit–reveal randomness** works in a decentralized and transparent way.  
This game ensures fairness — even the owner can’t cheat — and all players can verify every step on the blockchain.

---

## 🧩 Project Description

This project is a **simple blockchain-based guessing game** written in Solidity.  
The idea is to create a **transparent and trustless game** where:

- The owner commits to a secret number *before* anyone starts guessing.  
- Players place their guesses by sending a small amount of Ether.  
- Later, the owner **reveals** the secret, and those who guessed correctly **win the prize pool**.  

No centralized control, no hidden manipulations — everything is verifiable on-chain.

---

## 🚀 What It Does

1. **Owner commits a secret hash** (made from a secret number + random salt).  
2. **Players submit guesses** (numbers) along with their bets.  
3. After all guesses are in, the **owner reveals the secret**, proving it matches the earlier commitment.  
4. The smart contract **automatically determines winners** and allows them to claim their share of the prize.  
5. If the owner fails to reveal in time, **players can get refunds**.

All transactions are logged on the blockchain, providing full transparency.

---

## ✨ Features

- ✅ **Fair play** using the *commit–reveal* pattern  
- 🔒 **Immutable secrets** — no way to change after committing  
- 💰 **Automatic prize distribution** among winners  
- ⏰ **Refund mechanism** if the owner doesn’t reveal  
- 🌐 **Beginner-friendly** code with detailed comments  
- ⚙️ **Upgradeable design** — easy to extend with Chainlink VRF for secure randomness  

---

## 🔗 Deployed Smart Contract

**Contract Address:** `https://celo-sepolia.blockscout.com/address/0x65E41D336Ea4ad46c132eeA35308939693419075`  

