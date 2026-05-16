// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title CS-01: Reentrancy Vulnerability Case Study
/// @notice BEFORE: Naive ETH pool sends value before zeroing state — attacker re-enters and drains it.
///         AFTER:  CEI pattern + ReentrancyGuard block the attack completely.

// ─── BEFORE: Vulnerable (Interactions before Effects) ────────────────────────

contract VulnerableETHPool {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @dev BUG: sends ETH (interaction) before zeroing balance (effect)
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        (bool ok,) = msg.sender.call{value: amount}(""); // ← attacker re-enters here
        require(ok, "Transfer failed");
        balances[msg.sender] = 0; // too late — already re-entered
    }
}

contract ReentrancyAttacker {
    VulnerableETHPool public target;
    uint256 public stolenAmount;

    constructor(VulnerableETHPool target_) {
        target = target_;
    }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw();
    }

    receive() external payable {
        stolenAmount += msg.value;
        if (address(target).balance >= msg.value) {
            target.withdraw(); // re-enter before state is zeroed
        }
    }
}

// ─── AFTER: Fixed (CEI + ReentrancyGuard) ────────────────────────────────────

contract FixedETHPool is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    /// @dev FIXED: Effects before Interactions; nonReentrant as second defence layer
    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "Nothing to withdraw");
        balances[msg.sender] = 0; // Effect first
        (bool ok,) = msg.sender.call{value: amount}(""); // then Interaction
        require(ok, "Transfer failed");
    }
}

contract FixedReentrancyAttacker {
    FixedETHPool public target;
    bool public attackWasBlocked;

    constructor(FixedETHPool target_) {
        target = target_;
    }

    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw(); // legitimate withdraw of own funds
    }

    receive() external payable {
        // try to re-enter — ReentrancyGuard will revert; absorb the revert
        try target.withdraw() {} catch {
            attackWasBlocked = true;
        }
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

contract CS01_ReentrancyTest is Test {
    address public victim = makeAddr("victim");
    address public attacker = makeAddr("attacker");

    /// @notice BEFORE: reentrancy attack successfully drains VulnerableETHPool
    function test_before_reentrancy_drains_pool() public {
        VulnerableETHPool pool = new VulnerableETHPool();
        ReentrancyAttacker hack = new ReentrancyAttacker(pool);

        // Victim deposits 10 ETH legitimately
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        pool.deposit{value: 10 ether}();

        // Attacker deposits 1 ETH and launches attack
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        hack.attack{value: 1 ether}();

        // Attacker stole victim funds — pool is completely drained
        assertGt(hack.stolenAmount(), 1 ether, "Attacker must have stolen more than deposited");
        assertEq(address(pool).balance, 0, "Pool must be fully drained");
    }

    /// @notice AFTER: FixedETHPool with CEI + ReentrancyGuard preserves victim funds
    function test_after_reentrancyGuard_protects_pool() public {
        FixedETHPool pool = new FixedETHPool();
        FixedReentrancyAttacker hack = new FixedReentrancyAttacker(pool);

        // Victim deposits 10 ETH legitimately
        vm.deal(victim, 10 ether);
        vm.prank(victim);
        pool.deposit{value: 10 ether}();

        // Attacker deposits 1 ETH and tries to attack
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        hack.attack{value: 1 ether}();

        // Re-entry was blocked; victim funds remain untouched
        assertTrue(hack.attackWasBlocked(), "ReentrancyGuard must have blocked the re-entry");
        assertEq(address(pool).balance, 10 ether, "Victim funds must be intact");
        assertEq(pool.balances(victim), 10 ether, "Victim balance must be unchanged");
    }
}
