⚡ Uniswap V3 Flash Loan Arbitrage Bot

📖 Project Overview

This is a professional-grade Flash Loan Arbitrage Bot built on Uniswap V3.

It leverages atomic transactions to borrow assets without collateral, execute profitable trades across decentralized exchanges (DEXs), and repay the loan within the same block. If the trade is not profitable, the transaction reverts, ensuring zero risk of capital loss (excluding gas fees).

🎯 Key Features

Atomic Flash Loans: Borrows millions in liquidity from Uniswap V3 pools without upfront collateral.

Dual-DEX Architecture: Designed to arbitrage between Uniswap V3 (Lender) and Uniswap V2/SushiSwap (Market).

Hybrid Testing: Utilizes both Hardhat (Integration Tests) and Foundry (Fuzz Testing & Mainnet Forking) for maximum reliability.

Security First: Implements ReentrancyGuard, Ownable, SafeERC20, and deterministic pool address verification to prevent spoofing attacks.

🏗️ System Architecture

The system uses a "Callback" pattern required by Uniswap V3. The logic is split into Trigger, Handler, and Execution.

sequenceDiagram
    participant User as 👨‍💻 Owner
    participant Bot as 🤖 FlashLoanArb
    participant Pool as 🏦 Uniswap V3 (Bank)
    participant Market as 🛒 SushiSwap (Market)

    Note over User, Market: The Atomic Transaction Loop (1 Block)

    User->>Bot: 1. requestFlashLoan(1M USDC)
    activate Bot
    Bot->>Pool: 2. flash(recipient=Bot, amount=1M)
    activate Pool
    Pool->>Bot: 3. Transfer 1M USDC
    
    Note right of Pool: Pool Pauses & Waits for Callback
    Pool->>Bot: 4. uniswapV3FlashCallback(fee, data)
    
    activate Bot
    Note right of Bot: 5. Arbitrage Logic
    Bot->>Market: 6. Swap 1M USDC -> ETH -> 1.02M USDC
    Market-->>Bot: Returns 1.02M USDC
    
    Note right of Bot: 7. Repayment Calculation
    Bot->>Pool: 8. Transfer 1,000,500 USDC (Loan + Fee)
    deactivate Pool
    
    Note right of Bot: 9. Profit Check
    Bot->>Bot: require(Balance > 0)
    deactivate Bot
    
    Bot-->>User: Transaction Complete (Profit Kept in Contract)


🛠️ Technical Stack

Component

Technology

Purpose

Smart Contracts

Solidity ^0.8.20

Core logic using modern syntax.

Deployment

Hardhat + TypeScript

Scriptable deployment to local/testnet chains.

Simulation

Foundry (Forge)

Advanced EVM state manipulation (vm.etch) and fuzz testing.

Mocking

Custom Mocks

MockPool.sol acts as both V3 Pool and V2 Router for unit tests.

Security

OpenZeppelin

Standardized security modules (SafeERC20, Ownable).



🧪 Testing Strategy

The project employs a dual-layer testing strategy to ensure robustness.

Level 1: Unit Testing (Hardhat)

Uses MockPool.sol and MockToken.sol to simulate the flash loan lifecycle in a controlled environment.

Command: npx hardhat test

Validates: Request encoding, Callback execution, Repayment logic, Profit calculation.

Level 2: Fuzz Testing (Foundry)

Uses forge to blast the contract with random inputs to find edge cases where the math might fail.

Command:

nts/