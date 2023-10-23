// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/Script.sol";
import {AgoraNounsGovernor} from "src/AgoraNounsGovernor.sol";
import {AgoraNounsGovernorSepolia} from "test/mocks/AgoraNounsGovernorSepoliaMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public returns (address agoraGovernor) {
        vm.startBroadcast(deployerPrivateKey);

        address implementation = address(new AgoraNounsGovernorSepolia());
        bytes memory data = abi.encodeCall(AgoraNounsGovernorSepolia.initialize, ());
        agoraGovernor = address(new ERC1967Proxy(implementation, data));

        vm.stopBroadcast();
    }
}
