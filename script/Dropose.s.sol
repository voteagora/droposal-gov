// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8;

import "forge-std/Script.sol";
import {AgoraNounsGovernor} from "src/AgoraNounsGovernor.sol";
import {
    AgoraNounsGovernorSepolia,
    DroposalParams,
    NFTType,
    ERC721Params
} from "test/mocks/AgoraNounsGovernorSepoliaMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DroposeScript is Script {
    uint256 pk = vm.envUint("PRIVATE_KEY");
    AgoraNounsGovernorSepolia public governor =
        AgoraNounsGovernorSepolia(payable(0x5Cef0380cE0aD3DAEefef8bDb85dBDeD7965adf9));

    function run() public returns (uint256 proposalId) {
        DroposalParams memory droposalParams = DroposalParams({
            droposalType: 0, // Standard
            nftType: NFTType.ERC721,
            nftCollection: address(0),
            proposalDescription: "## TestProp\nThis is a test prop",
            nftParams: abi.encode(
                ERC721Params({
                    name: "Test721",
                    symbol: "TST",
                    royaltyBPS: 0,
                    fundsRecipient: payable(address(1)),
                    imageURI: "ipfs://Qm",
                    animationURI: "",
                    description: "This is a nice description"
                })
                )
        });

        vm.startBroadcast(pk);

        proposalId = governor.dropose(droposalParams);

        vm.stopBroadcast();
    }
}
