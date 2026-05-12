# RWA Tokenization Platform

**Blockchain Technologies 2 — Final Project | Option C**

A production-grade decentralized protocol for tokenizing real-world assets (RWA) on-chain. Built on Arbitrum Sepolia with full DAO governance, ERC-4626 yield vault, RWA-collateralized lending, and Chainlink oracle integration.

---

## Architecture

```
┌──────────────┐   mint/burn   ┌─────────────────────────┐
│  RWAFactory  │──────────────▶│  RWAToken (UUPS proxy)  │
│ CREATE/CREATE2│               │  V1 → V2 upgrade path   │
└──────────────┘               └──────────┬──────────────┘
                                           │ collateral
                    ┌──────────────────────▼──────────────────────┐
                    │           LendingPool                        │
                    │  LTV 70% | Liquidation 80% | Linear IR       │
                    └──────────────────────┬──────────────────────┘
                                           │ asset
                    ┌──────────────────────▼──────────────────────┐
                    │           RWAVault (ERC-4626)                │
                    │     Yield-bearing shares for depositors      │
                    └──────────────────────────────────────────────┘

┌───────────────┐  price/PoR  ┌──────────────────────────────────┐
│   Chainlink   │────────────▶│   ChainlinkAdapter (interface)   │
│  Price + PoR  │             │   Staleness check + normalization │
└───────────────┘             └──────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                      DAO Governance                               │
│  GovernanceToken (ERC20Votes + Permit)                           │
│  RWAGovernor (1-day delay | 1-week period | 4% quorum | 1% thr) │
│  TimelockController (2-day delay) → Treasury                     │
└──────────────────────────────────────────────────────────────────┘
```

## Deployed Contracts (Arbitrum Sepolia)

| Contract | Address | Explorer |
|----------|---------|---------|
| GovernanceToken | `0x...` | [link]() |
| RWAToken (proxy) | `0x...` | [link]() |
| RWAToken (impl V1) | `0x...` | [link]() |
| RWACertificate | `0x...` | [link]() |
| RWAVault | `0x...` | [link]() |
| LendingPool | `0x...` | [link]() |
| ChainlinkAdapter | `0x...` | [link]() |
| RWAFactory | `0x...` | [link]() |
| TimelockController | `0x...` | [link]() |
| RWAGovernor | `0x...` | [link]() |
| Treasury | `0x...` | [link]() |

## Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`curl -L https://foundry.paradigm.xyz | bash`)
- Node.js 20+

### Install dependencies

```bash
git clone https://github.com/AlmasAlkhan/Final-Project
cd Final-Project
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0 \
              OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.0 \
              smartcontractkit/chainlink \
              foundry-rs/forge-std
```

### Compile

```bash
forge build
```

### Run tests

```bash
# All tests (excluding fork)
forge test -vvv --no-match-path "test/fork/*"

# Fork tests (requires MAINNET_RPC_URL env var)
forge test --match-path "test/fork/*" --fork-url $MAINNET_RPC_URL -vvv

# Coverage report
forge coverage --no-match-path "test/fork/*" --report markdown > coverage-report.md
```

### Deploy to Arbitrum Sepolia

```bash
cp .env.example .env
# fill in your DEPLOYER_ADDRESS, PRICE_FEED_ADDRESS, POR_FEED_ADDRESS, BORROW_TOKEN_ADDRESS, PRIVATE_KEY

forge script script/Deploy.s.sol \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY
```

### Verify deployment

```bash
forge script script/Verify.s.sol \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc
```

## Team

| Member | Responsibility |
|--------|---------------|
| Person 1 | Smart contracts core: LendingPool, UUPS proxy (RWAToken V1→V2), RWAFactory, AssemblyUtils |
| Person 2 | Governance + Oracles: GovernanceToken, RWAGovernor, TimelockController, ChainlinkAdapter |
| Person 3 | Frontend + Subgraph + CI/CD |

## License

MIT
