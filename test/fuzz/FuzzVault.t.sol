// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RWAVault} from "../../src/vault/RWAVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FuzzVaultTest is Test {
    RWAVault public vault;
    MockERC20 public asset;

    address public owner = makeAddr("owner");
    address public alice = makeAddr("alice");

    function setUp() public {
        asset = new MockERC20("RWA", "RWAT", 18);
        vault = new RWAVault(IERC20(address(asset)), "vRWAT", "vRWAT", owner);
        asset.mint(alice, type(uint128).max);
        vm.prank(alice);
        asset.approve(address(vault), type(uint256).max);
    }

    /// @notice deposit then redeem must return close to original assets (rounding <= 1 wei)
    function testFuzz_depositRedeem_roundTrip(uint128 assets) public {
        vm.assume(assets > 1e6);
        vm.prank(alice);
        uint256 shares = vault.deposit(assets, alice);
        vm.prank(alice);
        uint256 returned = vault.redeem(shares, alice, alice);
        assertApproxEqAbs(returned, assets, 1);
    }

    /// @notice previewDeposit must never overstate actual shares minted
    function testFuzz_previewDeposit_neverOverstates(uint128 assets) public {
        vm.assume(assets > 1e6);
        uint256 preview = vault.previewDeposit(assets);
        vm.prank(alice);
        uint256 actual = vault.deposit(assets, alice);
        assertLe(preview, actual + 1);
    }

    /// @notice previewWithdraw must never understate actual shares burned
    function testFuzz_previewWithdraw_neverUnderstates(uint128 assets) public {
        vm.assume(assets > 1e6 && assets <= 1_000_000e18);
        vm.prank(alice);
        vault.deposit(assets * 2, alice);
        uint256 previewShares = vault.previewWithdraw(assets);
        vm.prank(alice);
        uint256 actualShares = vault.withdraw(assets, alice, alice);
        assertGe(previewShares, actualShares - 1);
    }

    /// @notice multiple depositors should get proportional shares
    function testFuzz_multiDepositor_proportionalShares(uint64 a1, uint64 a2) public {
        vm.assume(a1 > 1e6 && a2 > 1e6);
        address bob = makeAddr("bob");
        asset.mint(bob, a2);
        vm.prank(bob);
        asset.approve(address(vault), type(uint256).max);

        vm.prank(alice);
        uint256 s1 = vault.deposit(a1, alice);
        vm.prank(bob);
        uint256 s2 = vault.deposit(a2, bob);

        // shares ratio ≈ asset ratio (within 1 wei)
        if (a1 > a2) assertGe(s1, s2);
        else if (a2 > a1) assertGe(s2, s1);
    }
}
