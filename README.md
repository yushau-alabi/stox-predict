# StoxPredict: Decentralized Prediction Markets on Stacks

A permissionless platform for creating and participating in prediction markets with automated payouts, built on the Stacks blockchain.

## Overview

StoxPredict enables decentralized prediction markets where users can stake STX tokens on asset price movements. The platform features oracle-resolved settlements, automated winner distribution, and full transparency through on-chain operations.

## Key Features

- **Permissionless Market Creation**: Create markets for any asset with custom timeframes
- **Binary Predictions**: Stake on "up" or "down" price movements
- **Oracle Integration**: Automated settlement through trusted price feeds
- **Proportional Payouts**: Winners receive shares proportional to their stakes
- **Platform Fees**: Sustainable 2% fee structure for platform operations
- **Transparent Operations**: All activities recorded on-chain

## System Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Market Creator │    │   Participants  │    │   Oracle        │
│   (Owner)        │    │   (Users)       │    │   (Price Feed)  │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          │ create-market        │ make-prediction       │ resolve-market
          ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    StoxPredict Contract                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Markets   │  │    User     │  │    Administrative       │ │
│  │    Map      │  │ Predictions │  │      Functions          │ │
│  │             │  │     Map     │  │                         │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Contract Architecture

### Data Structures

#### Markets Map

```clarity
{
  start-price: uint,      // Initial asset price
  end-price: uint,        // Final asset price at resolution
  total-up-stake: uint,   // Total STX staked on price increase
  total-down-stake: uint, // Total STX staked on price decrease
  start-block: uint,      // Prediction window opens
  end-block: uint,        // Prediction window closes
  resolved: bool          // Settlement status
}
```

#### User Predictions Map

```clarity
{
  market-id: uint,
  user: principal
} -> {
  prediction: string-ascii, // "up" or "down"
  stake: uint,             // STX amount staked
  claimed: bool            // Payout claim status
}
```

### Configuration Variables

- **Oracle Address**: Trusted price feed provider
- **Minimum Stake**: 1 STX minimum participation threshold
- **Fee Percentage**: 2% platform fee on winnings
- **Market Counter**: Incremental market ID tracker

## Data Flow

### 1. Market Creation

```
Owner → create-market(start-price, start-block, end-block)
        ↓
    Market stored with ID
        ↓
    Market counter incremented
```

### 2. Prediction Phase

```
User → make-prediction(market-id, "up"/"down", stake-amount)
       ↓
   Validate timing & parameters
       ↓
   Transfer STX to contract
       ↓
   Record user prediction
       ↓
   Update market totals
```

### 3. Market Resolution

```
Oracle → resolve-market(market-id, final-price)
         ↓
     Validate oracle authority
         ↓
     Set end-price & resolved status
```

### 4. Payout Distribution

```
Winner → claim-winnings(market-id)
         ↓
     Calculate proportional share
         ↓
     Deduct platform fee (2%)
         ↓
     Transfer winnings to user
         ↓
     Transfer fee to contract owner
         ↓
     Mark prediction as claimed
```

## Core Functions

### Public Functions

| Function | Description | Access |
|----------|-------------|--------|
| `create-market` | Create new prediction market | Owner only |
| `make-prediction` | Stake STX on price prediction | Any user |
| `resolve-market` | Set final price and resolve market | Oracle only |
| `claim-winnings` | Claim proportional winnings | Winners only |

### Administrative Functions

| Function | Description |
|----------|-------------|
| `set-oracle-address` | Update oracle provider |
| `set-minimum-stake` | Adjust minimum participation |
| `set-fee-percentage` | Modify platform fee rate |
| `withdraw-fees` | Extract accumulated fees |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-market` | Retrieve market details |
| `get-user-prediction` | Get user's prediction info |
| `get-contract-balance` | Check contract STX balance |

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `ERR-OWNER-ONLY` | Unauthorized admin access |
| u101 | `ERR-NOT-FOUND` | Market/prediction not found |
| u102 | `ERR-INVALID-PREDICTION` | Invalid prediction parameters |
| u103 | `ERR-MARKET-CLOSED` | Market outside active window |
| u104 | `ERR-ALREADY-CLAIMED` | Winnings already claimed |
| u105 | `ERR-INSUFFICIENT-BALANCE` | Insufficient STX balance |
| u106 | `ERR-INVALID-PARAMETER` | Invalid function parameter |

## Usage Example

### Creating a Market

```clarity
;; Create Bitcoin price prediction market
(create-market u50000 u1000 u2000) ;; $50k start, blocks 1000-2000
```

### Making a Prediction

```clarity
;; Stake 5 STX on Bitcoin price going up
(make-prediction u0 "up" u5000000)
```

### Claiming Winnings

```clarity
;; Claim winnings after market resolution
(claim-winnings u0)
```

## Security Features

- **Principal-based Access Control**: Owner and oracle permissions
- **Block Height Validation**: Time-based market windows
- **Balance Verification**: Prevents over-staking
- **Claim Protection**: Prevents double-spending winnings
- **Parameter Validation**: Input sanitization and bounds checking

## Deployment Requirements

- Stacks blockchain compatibility
- STX token handling capability
- Oracle integration for price feeds
- Administrative key management

## License

This project is provided as-is for educational and development purposes.
