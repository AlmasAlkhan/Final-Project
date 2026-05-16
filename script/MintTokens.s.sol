// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RWAToken} from "../src/tokens/RWAToken.sol";

contract MintTokensScript is Script {
    address constant RWA_TOKEN_PROXY = 0x9E42552953aB57643BcfE9538e6A836efd6460c2;
    address constant RECIPIENT       = 0x8EACdfe5d389f1378C78F0BdfDfa1Dae408bca4F;

    function run() external {
        vm.startBroadcast();
        RWAToken(RWA_TOKEN_PROXY).mint(RECIPIENT, 1000e18);
        console2.log("Minted 1000 RWAT to", RECIPIENT);
        vm.stopBroadcast();
    }
}
