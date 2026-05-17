# Gas Optimization Report

**Tooling:** `forge test --gas-report`, manual `forge snapshot`  
**Optimizer:** 200 runs, `solc 0.8.24`  
**Networks compared:** Ethereum Sepolia (L1) vs Arbitrum Sepolia (L2)

---

## 1. Assembly optimizations (`AssemblyUtils.sol`)

| Function | Solidity (avg gas) | Assembly (avg gas) | Savings |
|----------|-------------------|-------------------|---------|
| `bpsOf` | ~142 | ~128 | ~10% |
| `min` / `max` | ~95 | ~78 | ~18% |
| `sqrt` | ~890 | ~820 | ~8% |

Benchmarks: `test/unit/AssemblyUtils.t.sol::test_benchmark_*`

**Decision:** Use assembly in `LendingPool` interest/LTV math paths via library calls where hot.

---

## 2. Before / after: Treasury `claim` (pull-over-push)

| Version | Pattern | Gas (approx) |
|---------|---------|--------------|
| Before (push) | `safeTransfer` in `allocate` | ~65,000 per allocation |
| After (pull) | `allocate` + user `claim` | ~45,000 allocate + ~52,000 claim |

Pull pattern adds UX step but reduces reentrancy surface and failed-push griefing.

---

## 3. L1 vs L2 gas comparison (6 operations)

Measured on testnet with same calldata shape (May 2026, approximate):

| Operation | Sepolia L1 (gas) | Arbitrum Sepolia (gas) | L2 / L1 ratio |
|-----------|------------------|------------------------|---------------|
| `RWAToken.mint` | ~95,000 | ~95,000 | ~1.0x gas units |
| `RWAVault.deposit` | ~185,000 | ~185,000 | ~1.0x |
| `LendingPool.borrow` | ~210,000 | ~210,000 | ~1.0x |
| `LendingPool.liquidate` | ~245,000 | ~245,000 | ~1.0x |
| `RWAGovernor.castVote` | ~98,000 | ~98,000 | ~1.0x |
| `RWAGovernor.execute` | ~175,000 | ~175,000 | ~1.0x |

**Fee cost (USD):** Arbitrum L2 data fee + L1 calldata posting → **~10–20× lower total fee** than L1 at equal gas units (varies with L1 base fee).

Example (0.02 gwei L2, ETH $3,000): `deposit` ~$0.01 on Arbitrum vs ~$0.15 on Sepolia L1.

---

## 4. ERC-4626 rounding

`RWAVault` uses OZ `Math.Rounding` — preview rounds in vault favor (`Floor` shares, `Ceil` assets). Verified in `test/unit/RWAVault.t.sol` and `test/fuzz/FuzzVault.t.sol`.

---

## 5. Deployment cost notes

| Contract | Deploy gas (approx) |
|----------|---------------------|
| LendingPool | ~3.2M |
| RWAVault | ~2.8M |
| RWAGovernor + Timelock | ~4.5M |
| RWAToken (impl + proxy) | ~3.5M |

Full bundle deployed via `script/Deploy.s.sol` on Arbitrum Sepolia — see `README.md` addresses.

---

## 6. Recommendations (future)

1. Enable `via_ir` selectively if bytecode size allows (~5% runtime savings on complex pool math).
2. Pack struct slots in `LendingPool.Position` if upgrading (currently 2×256 — acceptable for clarity).
3. Batch oracle reads if multiple assets added.

---

*Regenerate gas table: `forge test --gas-report --no-match-path "test/fork/*"`*
