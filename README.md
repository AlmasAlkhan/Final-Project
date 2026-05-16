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

## Deployed Contracts (Arbitrum Sepolia, chain 421614)

| Contract | Address | Explorer |
|----------|---------|---------|
| GovernanceToken | `0x1AB6Ae8A96e85A70a39BA944b8Fb12BB67Dd20Fc` | [link](https://sepolia.arbiscan.io/address/0x1AB6Ae8A96e85A70a39BA944b8Fb12BB67Dd20Fc) |
| RWAToken (proxy) | `0x24029BC435935451045D46dE0CF5c165bC08Da0B` | [link](https://sepolia.arbiscan.io/address/0x24029BC435935451045D46dE0CF5c165bC08Da0B) |
| RWACertificate | `0xa6087B3f8B509CC9bcA6616FA43Fe8EAFfEe5B94` | [link](https://sepolia.arbiscan.io/address/0xa6087B3f8B509CC9bcA6616FA43Fe8EAFfEe5B94) |
| RWAVault | `0x29FABA4ed78F47d9b567fC8B0fA8ccE4b78ac0c2` | [link](https://sepolia.arbiscan.io/address/0x29FABA4ed78F47d9b567fC8B0fA8ccE4b78ac0c2) |
| LendingPool | `0xC354B84cb424e82EeB0D321b2df4D2e787FD6232` | [link](https://sepolia.arbiscan.io/address/0xC354B84cb424e82EeB0D321b2df4D2e787FD6232) |
| ChainlinkAdapter | `0x62d67B4F0DB7a0807DeC6d3BFf937Bc07403C282` | [link](https://sepolia.arbiscan.io/address/0x62d67B4F0DB7a0807DeC6d3BFf937Bc07403C282) |
| RWAFactory | `0x56EA1b0767508503435B42391510cfF043A99564` | [link](https://sepolia.arbiscan.io/address/0x56EA1b0767508503435B42391510cfF043A99564) |
| TimelockController | `0x1A7A956c94cAe288d8630655502bC1Da441F7907` | [link](https://sepolia.arbiscan.io/address/0x1A7A956c94cAe288d8630655502bC1Da441F7907) |
| RWAGovernor | `0x1595Be7b5393f12a0A3A8eA08ddf7519b7Bd127e` | [link](https://sepolia.arbiscan.io/address/0x1595Be7b5393f12a0A3A8eA08ddf7519b7Bd127e) |
| Treasury | `0x3fe9a09d448918cf354d980ee06215301a76BC0F` | [link](https://sepolia.arbiscan.io/address/0x3fe9a09d448918cf354d980ee06215301a76BC0F) |

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
