# Post-Deployment Verification Output

Run on Arbitrum Sepolia after deploy:

```bash
export TIMELOCK_ADDRESS=0x19174b8cA8cDFF402A18B6a3ffe6Be924c2458E6
export GOVERNOR_ADDRESS=0xC7FBe95018f1A8Ab44Ea82c18C5a7dC1Cf8029aD
export GOV_TOKEN_ADDRESS=0xA9C4dD622546de3F7fFDD02a905b6dc699098f86
export VAULT_ADDRESS=0x112b3f5DA4625B721E419671a5800C6316e3ae97

forge script script/Verify.s.sol --rpc-url https://sepolia-rollup.arbitrum.io/rpc
```

## Expected output (reference)

```
=== POST-DEPLOYMENT VERIFICATION ===
Timelock min delay (seconds): 172800
PASS: Timelock delay = 2 days
Governor voting delay: 86400
PASS: Voting delay = 1 day
Governor voting period: 604800
PASS: Voting period = 1 week
GovToken owner: 0x19174b8cA8cDFF402A18B6a3ffe6Be924c2458E6
PASS: GovToken owned by Timelock
PASS: Governor has PROPOSER_ROLE on Timelock

=== ALL CHECKS PASSED ===
```

Commit hash verified: see `git rev-parse HEAD` at submission time.
