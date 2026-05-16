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

## Deployed Contracts (Ethereum Sepolia, chain 11155111)

| Contract | Address | Explorer |
|----------|---------|---------|
| GovernanceToken | `0x19174b8cA8cDFF402A18B6a3ffe6Be924c2458E6` | [link](https://sepolia.etherscan.io/address/0x19174b8cA8cDFF402A18B6a3ffe6Be924c2458E6) |
| RWAToken (proxy) | `0x039baa302696F9fB5EB5495f89DC479d09264404` | [link](https://sepolia.etherscan.io/address/0x039baa302696F9fB5EB5495f89DC479d09264404) |
| RWAToken (impl V1) | `0x9E42552953aB57643BcfE9538e6A836efd6460c2` | [link](https://sepolia.etherscan.io/address/0x9E42552953aB57643BcfE9538e6A836efd6460c2) |
| RWACertificate | `0x112b3f5DA4625B721E419671a5800C6316e3ae97` | [link](https://sepolia.etherscan.io/address/0x112b3f5DA4625B721E419671a5800C6316e3ae97) |
| RWAVault | `0x57592da359112B36ffE81d2398fD47C64A4C1bEf` | [link](https://sepolia.etherscan.io/address/0x57592da359112B36ffE81d2398fD47C64A4C1bEf) |
| LendingPool | `0x80E809ea83D92E049D0B22A51570dfC3344CF9Cc` | [link](https://sepolia.etherscan.io/address/0x80E809ea83D92E049D0B22A51570dfC3344CF9Cc) |
| ChainlinkAdapter | `0x3dbF7d0CcB978B1E270421616F394DE43FC52Ad5` | [link](https://sepolia.etherscan.io/address/0x3dbF7d0CcB978B1E270421616F394DE43FC52Ad5) |
| RWAFactory | `0xC9474cFC3Bb2AA5649aCCb17a9DD7591f3812Cb4` | [link](https://sepolia.etherscan.io/address/0xC9474cFC3Bb2AA5649aCCb17a9DD7591f3812Cb4) |
| TimelockController | `0xC7FBe95018f1A8Ab44Ea82c18C5a7dC1Cf8029aD` | [link](https://sepolia.etherscan.io/address/0xC7FBe95018f1A8Ab44Ea82c18C5a7dC1Cf8029aD) |
| RWAGovernor | `0x2501117e6989c5587a962693Feda5474d46B35df` | [link](https://sepolia.etherscan.io/address/0x2501117e6989c5587a962693Feda5474d46B35df) |
| Treasury | `0xFc622aC612a816f8001E7A198F2ECC4AC320D14f` | [link](https://sepolia.etherscan.io/address/0xFc622aC612a816f8001E7A198F2ECC4AC320D14f) |

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
