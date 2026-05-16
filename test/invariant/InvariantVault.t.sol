// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RWAVault} from "../../src/vault/RWAVault.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Invariant: totalAssets ≥ total redeemable assets; shares/assets accounting never drifts
contract InvariantVaultTest is Test {
    RWAVault public vault;
    MockERC20 public asset;
    VaultHandler public handler;

    function setUp() public {
        asset = new MockERC20("RWAT", "RWAT", 18);
        vault = new RWAVault(IERC20(address(asset)), "vRWAT", "vRWAT", address(this));
        handler = new VaultHandler(vault, asset);
        targetContract(address(handler));
    }

    /// @notice Total assets held by vault must be >= assets redeemable for all shares
    function invariant_totalAssetsGteRedeemable() public view {
        uint256 totalShares = vault.totalSupply();
        if (totalShares == 0) return;
        uint256 redeemable = vault.convertToAssets(totalShares);
        assertGe(vault.totalAssets(), redeemable - 1); // allow 1 wei rounding
    }

    /// @notice Sum of individual balances equals total supply
    function invariant_totalSupplyMatchesBalances() public view {
        uint256 sum = vault.balanceOf(handler.depositor1()) + vault.balanceOf(handler.depositor2());
        assertEq(vault.totalSupply(), sum);
    }

    /// @notice convertToShares(convertToAssets(x)) <= x (no free money)
    function invariant_noFreeShareMinting() public view {
        uint256 shares = vault.totalSupply();
        if (shares == 0) return;
        uint256 assets = vault.convertToAssets(shares);
        uint256 sharesBack = vault.convertToShares(assets);
        assertLe(sharesBack, shares + 1); // rounding
    }
}

contract VaultHandler is Test {
    RWAVault public vault;
    MockERC20 public asset;
    address public depositor1 = makeAddr("depositor1");
    address public depositor2 = makeAddr("depositor2");

    constructor(RWAVault vault_, MockERC20 asset_) {
        vault = vault_;
        asset = asset_;
        asset.mint(depositor1, type(uint128).max);
        asset.mint(depositor2, type(uint128).max);
        vm.prank(depositor1);
        asset.approve(address(vault), type(uint256).max);
        vm.prank(depositor2);
        asset.approve(address(vault), type(uint256).max);
    }

    function deposit1(uint128 amount) public {
        vm.assume(amount > 1e6);
        vm.prank(depositor1);
        vault.deposit(amount, depositor1);
    }

    function deposit2(uint128 amount) public {
        vm.assume(amount > 1e6);
        vm.prank(depositor2);
        vault.deposit(amount, depositor2);
    }

    function redeem1(uint128 shares) public {
        uint256 bal = vault.balanceOf(depositor1);
        if (bal == 0) return;
        uint256 toRedeem = shares % bal + 1;
        vm.prank(depositor1);
        vault.redeem(toRedeem, depositor1, depositor1);
    }

    function redeem2(uint128 shares) public {
        uint256 bal = vault.balanceOf(depositor2);
        if (bal == 0) return;
        uint256 toRedeem = shares % bal + 1;
        vm.prank(depositor2);
        vault.redeem(toRedeem, depositor2, depositor2);
    }
}
