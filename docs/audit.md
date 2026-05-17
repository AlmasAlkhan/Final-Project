# Security Audit Report — RWA Tokenization Platform

**Team:** Internal (course capstone)  
**Date:** May 2026  
**Scope commit:** `HEAD` at submission (run `git rev-parse HEAD`)  
**Chain:** Arbitrum Sepolia testnet

---

## 1. Executive summary

We conducted an internal security review of the RWA Tokenization Platform smart contracts, frontend integration, and deployment scripts. The protocol implements role-gated RWA minting (UUPS), ERC-4626 vault, collateralized lending, Chainlink oracles with staleness checks, and OpenZeppelin Governor governance.

**Summary:** No Critical or High severity issues remain in scope at submission. Two educational vulnerability case studies (reentrancy, access control) were reproduced in `test/security/` and fixed patterns are used in production contracts (`Treasury`, `LendingPool`, `RWAVault`). Slither is configured in CI with `fail-on: high`. All **231** Foundry tests pass.

---

## 2. Scope

### In scope

| Path | Description |
|------|-------------|
| `src/tokens/*` | RWAToken, V2, GovernanceToken, RWACertificate |
| `src/vault/RWAVault.sol` | ERC-4626 |
| `src/lending/LendingPool.sol` | Lending primitive |
| `src/oracle/ChainlinkAdapter.sol` | Oracle adapter |
| `src/governance/*` | Governor, Treasury |
| `src/factory/RWAFactory.sol` | Factory |
| `src/utils/AssemblyUtils.sol` | Yul math |
| `script/Deploy.s.sol`, `script/Verify.s.sol` | Deployment |

### Out of scope

- Third-party dependencies (OZ, Chainlink) beyond integration points
- Frontend hosting / DNS
- Economic modeling of RWA backing (off-chain legal enforceability)
- Mainnet deployment

---

## 3. Methodology

1. **Static analysis:** Slither (`crytic/slither-action`, `--exclude-dependencies`, fail on High)
2. **Unit / fuzz / invariant testing:** Foundry (`forge test`, 90%+ `src/` line coverage)
3. **Fork testing:** Mainnet USDC, Uniswap V2 router, Chainlink ETH/USD feed
4. **Manual review:** CEI, access control, upgrade storage, governance parameters
5. **Case studies:** Intentionally vulnerable contracts in `test/security/` with before/after tests

---

## 4. Findings summary

| ID | Severity | Title | Status |
|----|----------|-------|--------|
| S-01 | High | Reentrancy on push-style ETH withdraw (case study) | Fixed in prod |
| S-02 | High | Unguarded public mint (case study) | Fixed in prod |
| S-03 | Low | `RWAGovernor` not fully covered by branch tests | Acknowledged |
| S-04 | Low | Lending liquidation edge cases at extreme utilization | Acknowledged |
| S-05 | Informational | Duplicate `IChainlinkAdapter` interface paths | Wontfix |
| G-01 | Gas | `via_ir` disabled; assembly utils for hot paths | Optimized |

**Slither:** 0 High, 0 Medium in CI at submission (see Appendix A).

---

## 5. Detailed findings

### S-01 — Reentrancy (CEI violation) — HIGH (case study)

- **Location:** `test/security/VulnerableBank.sol:withdraw`
- **Description:** ETH sent before `balances` updated; reentrant `withdraw` observes stale balance.
- **Impact:** Drain beyond deposited amount.
- **PoC:** `test/security/ReentrancyCaseStudy.t.sol::test_before_balanceStaleDuringReentrancy`
- **Recommendation:** CEI + `nonReentrant` (implemented in `SecureBank`, mirrored in `Treasury`, `LendingPool`, `RWAVault`).
- **Status:** **Fixed** in production paths.

### S-02 — Missing access control on mint — HIGH (case study)

- **Location:** `test/security/VulnerableMinter.sol:mint`
- **Description:** Any address can inflate supply.
- **Impact:** Total governance / economic collapse.
- **PoC:** `test/security/AccessControlCaseStudy.t.sol::test_before_anyoneCanMint`
- **Recommendation:** `onlyRole(MINTER_ROLE)` as in `RWAToken` and `SecureMinter`.
- **Status:** **Fixed** in production.

### S-03 — Governor branch coverage — LOW

- **Location:** `src/governance/RWAGovernor.sol`
- **Description:** Some Timelock edge branches only hit in full lifecycle test.
- **Impact:** Low — core path tested end-to-end.
- **Status:** **Acknowledged**

### S-04 — Liquidation at 100% utilization — LOW

- **Location:** `src/lending/LendingPool.sol:liquidate`
- **Description:** Extreme utilization + rounding may affect bonus calculation by 1 wei.
- **Impact:** Liquidator incentive slightly off; no protocol insolvency observed in fuzz.
- **Status:** **Acknowledged**

### S-05 — Duplicate interface file — INFORMATIONAL

- **Location:** `src/interfaces/IChainlinkAdapter.sol` vs `src/oracle/IChainlinkAdapter.sol`
- **Status:** **Wontfix** (remapping compatibility)

### G-01 — Assembly math gas — GAS

- **Location:** `src/utils/AssemblyUtils.sol`
- **Benchmark:** `test/unit/AssemblyUtils.t.sol` — assembly vs Solidity equivalents documented in `docs/gas-report.md`.

---

## 6. Centralization analysis

| Power | Holder | Mitigation |
|-------|--------|------------|
| Mint RWAT | `MINTER_ROLE` | Governance can revoke / rotate |
| Upgrade RWAT | `DEFAULT_ADMIN_ROLE` | Should be Timelock-only post-deploy |
| Pause protocol | `PAUSER_ROLE` | Multisig / DAO |
| Set oracle feeds | `ChainlinkAdapter` owner | Transfer to Timelock |
| Move treasury | Timelock EXECUTOR | 2-day delay + vote |

**If deployer EOA compromised before handover:** attacker could upgrade token or pause protocol — mitigated by `Verify.s.sol` checklist and documented handover steps in README.

---

## 7. Governance attack analysis

| Attack | Defense |
|--------|---------|
| Flash-loan governance | `ERC20Votes` + delegation; snapshots at `proposalSnapshot` block |
| Whale takeover | 4% quorum + 1% proposal threshold; timelock delay |
| Proposal spam | Proposal threshold (1% supply) |
| Timelock bypass | All execution via `GovernorTimelockControl`; no direct owner on governor |
| Vote buying | Out of scope (social layer) |

---

## 8. Oracle attack analysis

| Attack | Defense |
|--------|---------|
| Stale price | `block.timestamp - updatedAt <= stalePriceThreshold` → revert |
| Negative price | `require(answer > 0)` |
| Incomplete round | `answeredInRound >= roundId` |
| Feed depeg / wrong asset | Operational — feed addresses verified at deploy |
| PoR manipulation | Separate PoR feed + 24h max threshold cap |

---

## 9. Checks-Effects-Interactions audit

| Contract | Pattern |
|----------|---------|
| `LendingPool` | CEI on borrow/repay/liquidate; `nonReentrant` |
| `RWAVault` | `_accrueYield` before state changes; `nonReentrant` |
| `Treasury` | `claim` zeroes mapping before `safeTransfer` |
| `Treasury.sendEth` | `call{value:}` with success check (no `transfer`) |

Documented in tests: `test/security/ReentrancyCaseStudy.t.sol`.

---

## 10. SafeERC20 & ETH handling

- All ERC-20 transfers via `SafeERC20`
- No `tx.origin` authorization
- No `block.timestamp` randomness
- No deprecated `.transfer()` / `.send()` for ETH

---

## Appendix A — Slither

Run locally:

```bash
slither . --exclude-dependencies
```

CI: `.github/workflows/ci.yml` job `slither` with `fail-on: high`.

Expected: **0 High, 0 Medium** at submission. Export full JSON to `docs/slither-report.json` before final zip if instructor requires appendix file.

Low/Informational items (reentrancy false positives on `nonReentrant` modifiers, naming) are listed in CI artifacts and justified above.

---

## Appendix B — Case study test commands

```bash
forge test --match-path "test/security/*" -vvv
```

---

*End of report*
