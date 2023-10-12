// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/Script.sol";
import {AgoraNounsGovernor} from "src/AgoraNounsGovernor.sol";

contract DeployScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public returns (AgoraNounsGovernor agoraGovernor) {
        vm.startBroadcast(deployerPrivateKey);

        agoraGovernor = new AgoraNounsGovernor();

        vm.stopBroadcast();
    }
}
