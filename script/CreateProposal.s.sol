// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RWAGovernor} from "../src/governance/RWAGovernor.sol";

contract CreateProposalScript is Script {
    address constant GOV_TOKEN  = 0xA9C4dD622546de3F7fFDD02a905b6dc699098f86;
    address constant GOVERNOR   = 0xC7FBe95018f1A8Ab44Ea82c18C5a7dC1Cf8029aD;
    address constant TREASURY   = 0xc557a92195350C268e1082b3542B58aDcA9142a1;
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
