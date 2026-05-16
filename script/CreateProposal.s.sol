// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RWAGovernor} from "../src/governance/RWAGovernor.sol";

contract CreateProposalScript is Script {
    address constant GOV_TOKEN  = 0x1AB6Ae8A96e85A70a39BA944b8Fb12BB67Dd20Fc;
    address constant GOVERNOR   = 0x1595Be7b5393f12a0A3A8eA08ddf7519b7Bd127e;
    address constant TREASURY   = 0x3fe9a09d448918cf354d980ee06215301a76BC0F;
    address constant DEPLOYER   = 0x8EACdfe5d389f1378C78F0BdfDfa1Dae408bca4F;

    function run() external {
        vm.startBroadcast();

        RWAGovernor governor = RWAGovernor(payable(GOVERNOR));

        // Deployer received 2% of MAX_SUPPLY during deployment and self-delegated.
        // Proposing RIP-1 to demonstrate full governance lifecycle.
        address[] memory targets = new address[](1);
        uint256[] memory values  = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);

        targets[0]   = TREASURY;
        values[0]    = 0;
        calldatas[0] = abi.encodeWithSignature("sendEth(address,uint256)", DEPLOYER, 0);

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            "RIP-1: Initialize RWA Platform treasury and establish governance lifecycle"
        );

        console2.log("Proposal created! ID:", proposalId);

        vm.stopBroadcast();
    }
}
