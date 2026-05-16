// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ChainlinkAdapter} from "../../src/oracle/ChainlinkAdapter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @notice Fork tests against real Chainlink mainnet feeds
/// Run with: forge test --fork-url $MAINNET_RPC_URL --match-contract ForkChainlinkTest
contract ForkChainlinkTest is Test {
    // Mainnet Chainlink ETH/USD feed
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    // Mainnet Chainlink BTC/USD feed (used as proxy for PoR feed in test)
    address constant BTC_USD_FEED = 0xF4030086522a5BeEA4988F8ca5B36DBC97Bee88b;

    ChainlinkAdapter public adapter;
    address public owner = makeAddr("owner");

    function setUp() public {
        uint256 mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"));
        vm.selectFork(mainnetFork);

        adapter = new ChainlinkAdapter(
            ETH_USD_FEED,
            BTC_USD_FEED,
            3600,   // 1 hour stale threshold
            86400,  // 24 hour reserve threshold
            owner
        );
    }

    function test_fork_getPrice_returnsPositive() public view {
        uint256 price = adapter.getPrice();
        assertGt(price, 0);
        console2.log("ETH/USD price (18 dec):", price);
    }

    function test_fork_getPrice_isReasonable() public view {
        uint256 price = adapter.getPrice();
        // ETH price should be between $100 and $100,000
        assertGt(price, 100e18);
        assertLt(price, 100_000e18);
    }

    function test_fork_getProofOfReserve_returnsPositive() public view {
        uint256 reserve = adapter.getProofOfReserve();
        assertGt(reserve, 0);
        console2.log("BTC/USD (proxy PoR, 18 dec):", reserve);
    }

    function test_fork_staleFeed_reverts() public {
        // Warp far enough into the future to make the feed stale
        vm.warp(block.timestamp + 7200);
        vm.expectRevert("ChainlinkAdapter: stale price");
        adapter.getPrice();
    }
}
