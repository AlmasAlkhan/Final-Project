# RWA Tokenization Platform — Architecture Document

**Course:** Blockchain Technologies 2 — Final Project (Option C)  
**Network:** Arbitrum Sepolia (L2)  
**Version:** 1.0

---

## 1. System context (C4 Level 1)

```
                    ┌─────────────────────────────────────────┐
                    │           External actors               │
                    │  Users | Issuers | Liquidators | DAO    │
                    └──────────────────┬──────────────────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
         v                             v                             v
  ┌──────────────┐              ┌──────────────┐              ┌──────────────┐
  │  Web dApp    │              │  The Graph   │              │  Chainlink   │
  │  (frontend)  │              │  Subgraph    │              │  Oracles     │
  └──────┬───────┘              └──────┬───────┘              └──────┬───────┘
         │ RPC read/write              │ GraphQL                     │ feeds
         v                             v                             v
  ┌──────────────────────────────────────────────────────────────────────────┐
  │              RWA Protocol (smart contracts on Arbitrum Sepolia)          │
  │  RWAToken (UUPS) | LendingPool | RWAVault (ERC-4626) | DAO | Treasury    │
  └──────────────────────────────────────────────────────────────────────────┘
```

The protocol tokenizes real-world asset exposure on-chain: issuers mint **RWAT** against collateral rules; users deposit into an **ERC-4626 vault**, borrow against RWA via **LendingPool**, and govern parameters through **OpenZeppelin Governor + Timelock**.

---

## 2. Container diagram

| Container | Responsibility | Key dependencies |
|-----------|----------------|------------------|
| `RWAToken` (UUPS proxy) | ERC-20 RWA unit; role-gated mint/burn; upgradeable to V2 | OZ Upgradeable, `RWAFactory` |
| `RWATokenV2` | Transfer fee + whitelist (append-only storage) | ERC-7201 namespaced slot |
| `RWAVault` | ERC-4626 yield on RWAT deposits | RWAT, linear yield accrual |
| `LendingPool` | Collateralized borrow, liquidation, linear IR | RWAT, USDC, `ChainlinkAdapter` |
| `ChainlinkAdapter` | Price + PoR with staleness checks | Chainlink aggregators |
| `RWACertificate` | ERC-721 ownership certificate | AccessControl |
| `GovernanceToken` | ERC20Votes + Permit | — |
| `RWAGovernor` | Propose / vote / queue / execute | Timelock |
| `TimelockController` | 2-day delay on privileged actions | Treasury control |
| `Treasury` | Pull-over-push allocations | Timelock EXECUTOR |
| `RWAFactory` | CREATE / CREATE2 deployments | Certificates, tokens |

**Proxy layout:** `RWAToken` implementation behind `ERC1967Proxy`; upgrades authorized by `DEFAULT_ADMIN_ROLE` (intended: Timelock after governance handover).

**Access-control roles:**

| Role | Contract | Capability |
|------|----------|------------|
| `MINTER_ROLE` | RWAToken | Mint / burn |
| `PAUSER_ROLE` | RWAToken, Vault, Pool, Certificate | Circuit breaker |
| `ISSUER_ROLE` | RWACertificate | Issue / revoke NFT |
| `EXECUTOR_ROLE` | Treasury | Allocate / sendEth |
| Timelock | All admin surfaces | DAO-controlled changes |

---

## 3. Sequence diagrams

### 3.1 Vault deposit

```
User -> RWAVault.deposit(assets)
  RWAVault -> _accrueYield()
  RWAVault -> RWAT.transferFrom(user, vault, assets)
  RWAVault -> mint shares to user
```

### 3.2 Governance: propose → vote → execute

```
Proposer -> RWAGovernor.propose(...)
  [voting delay 1 day]
  Voters -> castVote
  [voting period 1 week, quorum 4%]
  Anyone -> queue (via Timelock)
  [timelock 2 days]
  Anyone -> execute -> Timelock -> target contract
```

### 3.3 Borrow → liquidate

```
User -> LendingPool.depositCollateral(RWAT)
User -> LendingPool.borrow(USDC)  [LTV ≤ 70%]
  ... price moves / interest accrues ...
Liquidator -> LendingPool.liquidate(borrower)  [HF < 1]
  USDC repaid, RWAT bonus to liquidator
```

---

## 4. Storage layout & upgrade safety

### RWAToken (V1, upgradeable)

Linear OZ `Initializable` storage: balances, allowances, roles, `backingAsset`, `reserveRatio`, pause flag.

### RWATokenV2

V2 state in **ERC-7201** namespace (`V2_STORAGE_LOCATION`) — no collision with V1 linear layout:

- `transferFeeBps`, `feeRecipient`, `whitelistEnabled`, `mapping whitelist`

**Proof:** V2 never reorders V1 slots; only adds namespaced struct. Upgrade path tested in `test/unit/RWATokenV2.t.sol`.

---

## 5. Trust assumptions

| Actor | Trust level | Risk if compromised |
|-------|-------------|---------------------|
| Timelock (DAO) | High — controls mint policy, upgrades, treasury | Malicious proposals could drain treasury or upgrade token |
| Deployer EOA (bootstrap) | Temporary until roles revoked | Could retain admin if not transferred |
| Chainlink feeds | Price truth | Stale/manipulated prices → bad liquidations |
| Issuer (`ISSUER_ROLE`) | Medium | Could issue fraudulent certificates |

**Timelock powers:** execute arbitrary calls approved by governance; holds `GovernanceToken` owner; `Treasury` EXECUTOR.

**Admin backdoor mitigation:** `script/Verify.s.sol` checks Timelock delay, governor params, GovToken owner = Timelock.

---

## 6. Design patterns (documented)

| Pattern | Where | Justification |
|---------|-------|---------------|
| Factory | `RWAFactory` | Deterministic certificate deployment (CREATE2) |
| UUPS Proxy | `RWAToken` | Upgrade fee/whitelist without migration |
| CEI / ReentrancyGuard | Pool, Vault, Treasury | External token/ETH calls |
| Pull-over-push | `Treasury.claim` | Safer recipient withdrawals |
| Access Control | All privileged contracts | No unguarded admin |
| Pausable | Token, vault, pool | Emergency stop |
| Oracle adapter | `IChainlinkAdapter` | Swappable mocks in tests |
| Timelock | Governor stack | Delayed execution |
| State machine | Governor `ProposalState` | Lifecycle enforcement |

---

## 7. Architecture Decision Records (ADR)

### ADR-001: Lending vs AMM

**Context:** Option C requires DeFi primitive from scratch.  
**Decision:** Implement **RWA-collateralized lending** (LTV, HF, liquidation) instead of AMM.  
**Consequences:** (+) Matches RWA use case; (−) no swap UI.

### ADR-002: UUPS over Transparent Proxy

**Context:** Upgradeable RWA token required.  
**Decision:** UUPS — logic contract holds upgrade auth.  
**Consequences:** (+) Cheaper L2 deploys; (−) must not brick implementation.

### ADR-003: ERC-7201 for V2 storage

**Context:** Avoid storage collision on upgrade.  
**Decision:** Namespaced struct for V2-only fields.  
**Consequences:** (+) Provable isolation; (−) slightly higher read gas.

### ADR-004: Chainlink adapter interface

**Context:** Tests and L2 need mockable oracles.  
**Decision:** `IChainlinkAdapter` abstraction.  
**Consequences:** (+) Fork/unit flexibility; (−) extra indirection.

### ADR-005: The Graph for indexing

**Context:** Frontend must not scan all events on-chain.  
**Decision:** Subgraph with 9 entities, proposals + lending positions.  
**Consequences:** (+) Fast UI; (−) indexer lag / hosted dependency.

---

## 8. External dependencies

- **OpenZeppelin Contracts v5.0.0**
- **Chainlink aggregators** (price + PoR)
- **The Graph** (hosted Studio)
- **Arbitrum Sepolia** RPC + Arbiscan verification

---

*See also: `docs/audit.md`, `docs/gas-report.md`, `docs/graphql-queries.md`.*
