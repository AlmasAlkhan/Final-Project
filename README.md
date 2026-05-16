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
| GovernanceToken | `0xF141123D1D89695cE734316E9629A49F348Fe772` | [link](https://sepolia.arbiscan.io/address/0xF141123D1D89695cE734316E9629A49F348Fe772) |
| RWAToken (proxy) | `0x5651264d129A5357F88c3E275Fe3825ad8E27335` | [link](https://sepolia.arbiscan.io/address/0x5651264d129A5357F88c3E275Fe3825ad8E27335) |
| RWACertificate | `0x9E645d667FC78C18913A11613b30088690B22AD5` | [link](https://sepolia.arbiscan.io/address/0x9E645d667FC78C18913A11613b30088690B22AD5) |
| RWAVault | `0x7a53514e945DaEBff7e50d9a8838a38166E65846` | [link](https://sepolia.arbiscan.io/address/0x7a53514e945DaEBff7e50d9a8838a38166E65846) |
| LendingPool | `0x7C1f511cc69D54038AfDE6B611309008225d8222` | [link](https://sepolia.arbiscan.io/address/0x7C1f511cc69D54038AfDE6B611309008225d8222) |
| ChainlinkAdapter | `0xc43d76Dd4dB338786f4d6a5b856Be167E8947Ae8` | [link](https://sepolia.arbiscan.io/address/0xc43d76Dd4dB338786f4d6a5b856Be167E8947Ae8) |
| RWAFactory | `0x347E0AaB0c43A3E6c544A8CEeB4Ed56bEF7e120B` | [link](https://sepolia.arbiscan.io/address/0x347E0AaB0c43A3E6c544A8CEeB4Ed56bEF7e120B) |
| TimelockController | `0x5151e254350d9414d3db354E35fB26beB461eb70` | [link](https://sepolia.arbiscan.io/address/0x5151e254350d9414d3db354E35fB26beB461eb70) |
| RWAGovernor | `0x9b8a09EF39C1c80f670eBbC0870eFb9f4DEd4337` | [link](https://sepolia.arbiscan.io/address/0x9b8a09EF39C1c80f670eBbC0870eFb9f4DEd4337) |
| Treasury | `0x2778d0646c1f9f7F182067BC28940fC145Ec3d88` | [link](https://sepolia.arbiscan.io/address/0x2778d0646c1f9f7F182067BC28940fC145Ec3d88) |

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
