// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

/// @title CS-02: Access Control Vulnerability Case Study
/// @notice BEFORE: Minting gateway has no caller check — anyone can mint governance tokens.
///         AFTER:  onlyOwner modifier restricts minting to the authorized owner only.

// ─── BEFORE: Vulnerable (no access control on privileged function) ────────────

contract VulnerableMinter {
    MockERC20 public token;

    constructor(MockERC20 token_) {
        token = token_;
    }

    /// @dev BUG: no role or ownership check — any caller can mint unlimited tokens
    function mint(address to, uint256 amount) external {
        token.mint(to, amount);
    }
}

// ─── AFTER: Fixed (Ownable guards the mint function) ─────────────────────────

contract FixedMinter is Ownable {
    MockERC20 public token;

    constructor(MockERC20 token_, address owner_) Ownable(owner_) {
        token = token_;
    }

    /// @dev FIXED: only the protocol owner may call mint
    function mint(address to, uint256 amount) external onlyOwner {
        token.mint(to, amount);
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

contract CS02_AccessControlTest is Test {
    address public owner = makeAddr("owner");
    address public attacker = makeAddr("attacker");
    MockERC20 public token;

    function setUp() public {
        token = new MockERC20("GovToken", "GOV", 18);
    }

    /// @notice BEFORE: attacker mints arbitrary governance tokens with no authorization
    function test_before_unauthorized_mint_succeeds() public {
        VulnerableMinter minter = new VulnerableMinter(token);

        uint256 mintAmount = 1_000_000e18;
        vm.prank(attacker);
        minter.mint(attacker, mintAmount); // succeeds — no access check!

        assertEq(token.balanceOf(attacker), mintAmount, "Attacker minted tokens without permission");
    }

    /// @notice AFTER: FixedMinter with onlyOwner blocks unauthorized mint
    function test_after_onlyOwner_preventsUnauthorizedMint() public {
        FixedMinter minter = new FixedMinter(token, owner);

        // Attacker attempt must revert
        vm.expectRevert();
        vm.prank(attacker);
        minter.mint(attacker, 1_000_000e18);

        // Authorized owner can still mint
        vm.prank(owner);
        minter.mint(owner, 500e18);

        assertEq(token.balanceOf(owner), 500e18, "Owner must be able to mint");
        assertEq(token.balanceOf(attacker), 0, "Attacker balance must remain zero");
    }
}
