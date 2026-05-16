// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GovernanceToken} from "../../src/tokens/GovernanceToken.sol";

contract FuzzGovernanceTest is Test {
    GovernanceToken public token;
    address public owner = makeAddr("owner");

    function setUp() public {
        token = new GovernanceToken(owner);
    }

    /// @notice voting power after delegation must equal minted amount
    function testFuzz_votingPower_afterDelegation(address voter, uint128 amount) public {
        vm.assume(voter != address(0));
        vm.assume(amount > 0 && amount <= token.MAX_SUPPLY());

        vm.prank(owner);
        token.mint(voter, amount);
        vm.prank(voter);
        token.delegate(voter);

        assertEq(token.getVotes(voter), amount);
    }

    /// @notice transferring tokens should shift voting power
    function testFuzz_votingPower_shiftsOnTransfer(uint128 amount, uint128 transferAmt) public {
        vm.assume(amount > 0 && amount <= token.MAX_SUPPLY());
        vm.assume(transferAmt > 0 && transferAmt <= amount);

        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        vm.prank(owner);
        token.mint(alice, amount);
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);

        vm.prank(alice);
        token.transfer(bob, transferAmt);

        assertEq(token.getVotes(alice), amount - transferAmt);
        assertEq(token.getVotes(bob), transferAmt);
    }

    /// @notice total supply never exceeds MAX_SUPPLY
    function testFuzz_totalSupply_neverExceedsMax(uint128 amount) public {
        vm.assume(amount <= token.MAX_SUPPLY());
        vm.prank(owner);
        token.mint(makeAddr("recipient"), amount);
        assertLe(token.totalSupply(), token.MAX_SUPPLY());
    }
}
