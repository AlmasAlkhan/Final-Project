// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  Security Case Study CS-02: Unprotected setOracle() in LendingPool     ║
// ║                                                                          ║
// ║  VULNERABILITY                                                           ║
// ║    A lending pool with no access control on setOracle() allows any      ║
// ║    address to replace the price oracle with a malicious contract that   ║
// ║    returns an inflated price. The attacker can then borrow far more     ║
// ║    than their collateral is worth, draining the pool's liquidity.       ║
// ║                                                                          ║
// ║  FIX                                                                     ║
// ║    onlyOwner modifier on setOracle(). Only the deployer / Timelock       ║
// ║    can swap the oracle — implemented in the real LendingPool.           ║
// ║                                                                          ║
// ║  TESTS                                                                   ║
// ║    BEFORE — attacker replaces oracle and drains the pool                ║
// ║    AFTER  — setOracle() reverts for unauthorized callers                ║
// ╚══════════════════════════════════════════════════════════════════════════╝

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IChainlinkAdapter} from "../../src/oracle/IChainlinkAdapter.sol";
import {LendingPool} from "../../src/lending/LendingPool.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {MockChainlinkAdapter} from "../mocks/MockChainlinkAdapter.sol";

// ─── Vulnerable contract ──────────────────────────────────────────────────────

/// @dev Minimal lending pool that is missing the onlyOwner guard on setOracle().
///      Everything else mirrors the real LendingPool logic at 70% LTV.
///      This is the state the contract was in BEFORE the fix.
contract VulnerableLendingPool {
    using SafeERC20 for IERC20;

    uint256 constant MAX_LTV   = 7000;   // 70%
    uint256 constant PRECISION = 1e18;

    IERC20 public immutable collateralToken;
    IERC20 public immutable borrowToken;
    IChainlinkAdapter public oracle;

    mapping(address => uint256) public collateral;
    uint256 public poolLiquidity;

    constructor(IERC20 col_, IERC20 borrow_, IChainlinkAdapter oracle_) {
        collateralToken = col_;
        borrowToken     = borrow_;
        oracle          = oracle_;
    }

    function fundPool(uint256 amount) external {
        borrowToken.safeTransferFrom(msg.sender, address(this), amount);
        poolLiquidity += amount;
    }

    function depositCollateral(uint256 amount) external {
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
    }

    // ❌ VULNERABLE: no onlyOwner — any address can swap the oracle
    function setOracle(IChainlinkAdapter newOracle) external {
        oracle = newOracle;
    }

    function borrow(uint256 amount) external {
        require(amount > 0,                  "Zero amount");
        require(amount <= poolLiquidity,      "Insufficient liquidity");

        uint256 price           = oracle.getPrice();
        uint256 collateralValue = (collateral[msg.sender] * price) / PRECISION;
        uint256 maxBorrow       = (collateralValue * MAX_LTV) / 10000;

        require(amount <= maxBorrow, "Exceeds max LTV");

        poolLiquidity -= amount;
        borrowToken.safeTransfer(msg.sender, amount);
    }
}

// ─── Malicious oracle ─────────────────────────────────────────────────────────

/// @dev Returns a wildly inflated price so attacker's small collateral appears
///      to be worth millions, bypassing the LTV check.
contract MaliciousOracle is IChainlinkAdapter {
    uint256 private immutable _inflatedPrice;

    constructor(uint256 inflatedPrice) {
        _inflatedPrice = inflatedPrice;
    }

    function getPrice() external view returns (uint256) {
        return _inflatedPrice;
    }

    function getProofOfReserve() external pure returns (uint256) {
        return 0;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}

// ─── Test contract ────────────────────────────────────────────────────────────

contract AccessControlCaseStudyTest is Test {
    address public owner    = makeAddr("owner");
    address public lp       = makeAddr("lp");       // legitimate liquidity provider
    address public attacker = makeAddr("attacker");

    // Real price: 1 RWAT = $100
    uint256 constant REAL_PRICE     = 100e18;
    // Malicious price: 1 RWAT = $1,000,000 (10 000× inflated)
    uint256 constant INFLATED_PRICE = 1_000_000e18;

    uint256 constant POOL_LIQUIDITY    = 1_000_000e18; // $1M in borrow token
    uint256 constant ATTACKER_COLLAT   = 100e18;        // 100 RWAT (real value $10,000)

    // ── CS-02 BEFORE ──────────────────────────────────────────────────────────

    /// @notice Demonstrates that an unguarded setOracle() lets an attacker
    ///         inject a malicious price feed and drain the lending pool.
    function test_CS02_BEFORE_accessControl_oracleManipulationDrainsPool() public {
        MockERC20 collToken  = new MockERC20("RWA Token",  "RWAT", 18);
        MockERC20 borrowToken = new MockERC20("USD Stable", "USD",  18);
        MockChainlinkAdapter realOracle = new MockChainlinkAdapter(REAL_PRICE, REAL_PRICE * 10);

        VulnerableLendingPool vuln = new VulnerableLendingPool(
            IERC20(address(collToken)),
            IERC20(address(borrowToken)),
            realOracle
        );

        // LP funds the pool with $1,000,000
        borrowToken.mint(lp, POOL_LIQUIDITY);
        vm.startPrank(lp);
        borrowToken.approve(address(vuln), POOL_LIQUIDITY);
        vuln.fundPool(POOL_LIQUIDITY);
        vm.stopPrank();

        // Attacker deposits 100 RWAT as collateral
        // Real value: 100 × $100 = $10,000 → legitimate max borrow = $7,000
        collToken.mint(attacker, ATTACKER_COLLAT);
        vm.startPrank(attacker);
        collToken.approve(address(vuln), ATTACKER_COLLAT);
        vuln.depositCollateral(ATTACKER_COLLAT);

        // ── Attack: replace oracle with malicious one ──────────────────────
        MaliciousOracle evil = new MaliciousOracle(INFLATED_PRICE);
        // No access control — anyone can call this
        vuln.setOracle(evil);

        // Malicious oracle says 100 RWAT = $100,000,000
        // 70% LTV → max borrow = $70,000,000 >> pool liquidity of $1,000,000
        // Attacker borrows entire pool
        uint256 poolBefore = borrowToken.balanceOf(address(vuln));
        vuln.borrow(POOL_LIQUIDITY);
        vm.stopPrank();

        uint256 poolAfter    = borrowToken.balanceOf(address(vuln));
        uint256 attackerGain = borrowToken.balanceOf(attacker);

        console2.log("Pool liquidity before attack:", poolBefore);
        console2.log("Pool liquidity after attack: ", poolAfter);
        console2.log("Attacker borrowed:           ", attackerGain);
        console2.log("Attacker's real collateral value: $",
            (ATTACKER_COLLAT * REAL_PRICE) / 1e18 / 1e18);

        // Pool is completely drained despite attacker depositing only $10,000
        assertEq(poolAfter, 0, "Pool should be drained");
        assertEq(attackerGain, POOL_LIQUIDITY, "Attacker should hold all pool liquidity");
    }

    // ── CS-02 AFTER ───────────────────────────────────────────────────────────

    /// @notice Demonstrates that the real LendingPool (onlyOwner on setOracle)
    ///         reverts when an unauthorized caller attempts oracle replacement.
    function test_CS02_AFTER_accessControl_setOracleRevertsForAttacker() public {
        MockERC20 collToken   = new MockERC20("RWA Token",  "RWAT", 18);
        MockERC20 borrowToken  = new MockERC20("USD Stable", "USD",  18);
        MockChainlinkAdapter realOracle = new MockChainlinkAdapter(REAL_PRICE, REAL_PRICE * 10);

        // Real LendingPool: setOracle() has onlyOwner
        LendingPool fixed_ = new LendingPool(
            IERC20(address(collToken)),
            IERC20(address(borrowToken)),
            realOracle,
            owner
        );

        // LP funds the pool
        borrowToken.mint(lp, POOL_LIQUIDITY);
        vm.startPrank(lp);
        borrowToken.approve(address(fixed_), POOL_LIQUIDITY);
        fixed_.provideLiquidity(POOL_LIQUIDITY);
        vm.stopPrank();

        // Attacker deploys malicious oracle
        MaliciousOracle evil = new MaliciousOracle(INFLATED_PRICE);

        // Attacker tries to replace the oracle — must revert
        vm.prank(attacker);
        vm.expectRevert();
        fixed_.setOracle(address(evil));

        // Pool liquidity is untouched
        assertEq(fixed_.availableLiquidity(), POOL_LIQUIDITY, "Pool must be unaffected");
        // Oracle is still the legitimate one
        assertEq(address(fixed_.oracle()), address(realOracle), "Oracle must not be replaced");

        console2.log("setOracle() correctly reverted for attacker");
        console2.log("Pool liquidity preserved:", fixed_.availableLiquidity());
    }

    /// @notice Confirms that the OWNER can still legitimately update the oracle.
    ///         Access control blocks attackers but does NOT break admin operations.
    function test_CS02_AFTER_accessControl_ownerCanUpdateOracle() public {
        MockERC20 collToken   = new MockERC20("RWA Token",  "RWAT", 18);
        MockERC20 borrowToken  = new MockERC20("USD Stable", "USD",  18);
        MockChainlinkAdapter realOracle  = new MockChainlinkAdapter(REAL_PRICE, REAL_PRICE * 10);
        MockChainlinkAdapter newOracle   = new MockChainlinkAdapter(REAL_PRICE * 2, REAL_PRICE * 20);

        LendingPool fixed_ = new LendingPool(
            IERC20(address(collToken)),
            IERC20(address(borrowToken)),
            realOracle,
            owner
        );

        // Owner (or Timelock in production) can update the oracle legitimately
        vm.prank(owner);
        fixed_.setOracle(address(newOracle));

        assertEq(address(fixed_.oracle()), address(newOracle), "Owner should be able to update oracle");
        console2.log("Owner oracle update succeeded - access control working correctly");
    }
}
