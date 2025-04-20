# ⚖️ Dexy DEX

A lightweight and educational **Decentralized Exchange (DEX)** built with Solidity. Dexy allows users to create token pairs, provide liquidity, redeem LP tokens, and swap assets. Each token pair has its own liquidity pool based on the **constant product formula (x * y = k)**.

---

## 🛠️ Contracts Overview

### 1. `Dexy.sol`
- Factory contract responsible for **creating token pairs**.
- Stores mapping of pairs and their corresponding liquidity pools.
- Emits an event when a new pair is created.

### 2. `DexyPool.sol`
- Handles **liquidity management and token swaps**.
- Mints LP tokens to liquidity providers.
- Allows redemption of LP tokens for corresponding assets.
- Swaps assets using the **x * y = k** formula.

### 3. `DexyLiquidityToken.sol`
- Custom ERC-20 LP token.
- Only mintable/burnable by its associated DexyPool.
- Tracks each user’s share in a specific pool.

---

## 🚀 Features

- 🔁 **Token Pair Creation**
- 💧 **Add Liquidity / Redeem Liquidity**
- 🔄 **Swap Between Tokens**
- 🪙 **Custom LP Tokens per Pair**
- 🔐 **Access Controlled LP Token Minting**

---

## 🧪 Example Workflow

1. ✅ Deploy `Dexy.sol`
2. ✅ Call `createPair(tokenA, tokenB, nameA, nameB)`
3. ✅ Call `addLiquidity` in the returned `DexyPool` address
4. ✅ Use `redeemLiquidityToken` to withdraw your share
5. ✅ Call `swapTokens` to swap between tokens in a pool

---

## 📦 Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
  - `ERC20`
  - `AccessControl`
  - `Math`

## Get Started
git clone https://github.com/your-username/dexy-dex.git
cd dexy-dex

## 📦 Install Dependencies
`forge install` &
`forge build`
`forge test`

## 🔬 Deploy Locally
`anvil`
forge script script/Deploy.s.sol --fork-url http://localhost:8545 --broadcast --private-key ANVIL_ACCOUNT_PRIVATE_KEY

