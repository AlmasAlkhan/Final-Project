// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RWAVault} from "../../src/vault/RWAVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract FuzzVaultTest is Test {
    RWAVault public vault;
    MockERC20 public asset;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        asset = new MockERC20("RWAToken", "RWAT", 18);
        vault = new RWAVault(IERC20(address(asset)), "RWA Vault", "vRWAT", owner);

        asset.mint(alice, type(uint128).max);
        asset.mint(bob, type(uint128).max);

        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);
    }

    /// @notice deposit must always yield non-zero shares
    function testFuzz_vault_deposit_givesNonZeroShares(uint64 amount) public {
        vm.assume(amount > 0);
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        assertGt(shares, 0);
    }

    /// @notice previewDeposit must never overstate actual shares received
    function testFuzz_vault_previewDeposit_neverOverstates(uint64 amount) public {
        vm.assume(amount > 0);
        uint256 preview = vault.previewDeposit(amount);
        vm.prank(alice);
        uint256 actual = vault.deposit(amount, alice);
        assertLe(preview, actual);
    }

    /// @notice deposit then full redeem: assets returned must never exceed assets deposited
    function testFuzz_vault_depositRedeem_roundtripAtMost(uint64 amount) public {
        vm.assume(amount > 1e6);
        vm.prank(alice);
        uint256 shares = vault.deposit(amount, alice);
        vm.prank(alice);
        uint256 assetsOut = vault.redeem(shares, alice, alice);
        assertLe(assetsOut, amount);
    }

    /// @notice totalAssets must be >= sum of all deposits (no yield rate set)
    function testFuzz_vault_multiDeposit_totalAssetsGteSum(uint64 amt1, uint64 amt2) public {
        vm.assume(amt1 > 0 && amt2 > 0);
        uint256 before = vault.totalAssets();
        vm.prank(alice);
        vault.deposit(amt1, alice);
        vm.prank(bob);
        vault.deposit(amt2, bob);
        assertGe(vault.totalAssets(), before + uint256(amt1) + uint256(amt2));
    }

    /// @notice maxWithdraw for a depositor must never exceed totalAssets
    function testFuzz_vault_maxWithdraw_neverExceedsTotalAssets(uint64 amount) public {
        vm.assume(amount > 0);
        vm.prank(alice);
        vault.deposit(amount, alice);
        uint256 maxW = vault.maxWithdraw(alice);
        assertLe(maxW, vault.totalAssets());
    }
}
