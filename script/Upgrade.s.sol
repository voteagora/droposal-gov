// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/Script.sol";
import {AgoraNounsGovernor} from "src/AgoraNounsGovernor.sol";
import {AgoraNounsGovernorSepolia} from "test/mocks/AgoraNounsGovernorSepoliaMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UpgradeScript is Script {
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

    function run() public returns (address newImplementation) {
        vm.startBroadcast(deployerPrivateKey);

        newImplementation = address(new AgoraNounsGovernorSepolia());
        AgoraNounsGovernorSepolia(payable(0x5Cef0380cE0aD3DAEefef8bDb85dBDeD7965adf9)).upgradeTo(newImplementation);

        vm.stopBroadcast();
    }
}
