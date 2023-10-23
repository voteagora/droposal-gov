// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {AgoraNounsGovernor, AgoraNounsGovernorMock} from "./mocks/AgoraNounsGovernorMock.sol";
import {AgoraNounsGovernorSepolia, AgoraNounsGovernorSepoliaMock} from "./mocks/AgoraNounsGovernorSepoliaMock.sol";
import {NounsReceiver} from "./mocks/NounsReceiver.sol";
import {IERC721Checkpointable} from "src/lib/openzeppelin/v1/GovernorVotesUpgradeable.sol";
import {IGovernorUpgradeable} from "src/lib/openzeppelin/v1/GovernorUpgradeable.sol";
import {IZoraCreator1155Factory} from "src/interfaces/IZoraCreator1155Factory.sol";
import {ISliceCore, Payee, SliceParams} from "src/interfaces/ISliceCore.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    DroposalParams, NFTType, ERC721Params, ERC1155Params, ERC1155TokenParams
} from "src/structs/DroposalParams.sol";

contract AgoraGovernorTest is Test {
    IERC721Checkpointable public constant nounsToken = IERC721Checkpointable(0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03);
    IGovernorUpgradeable public constant nounsGovernor =
        IGovernorUpgradeable(0x6f3E6272A167e8AcCb32072d08E0957F9c79223d);
    address public constant nounsTimelock = 0xb1a32FC9F9D8b2cf86C068Cae13108809547ef71;
    address public constant zoraNFTCreator721 = 0xF74B146ce44CC162b601deC3BE331784DB111DC1;
    IZoraCreator1155Factory public constant zoraCreator1155Factory =
        IZoraCreator1155Factory(0xA6C5f2DE915240270DaC655152C3f6A91748cb85);
    address public constant FIXED_PRICE_MINTER = 0x04E2516A2c207E84a1839755675dfd8eF6302F0a;
    ISliceCore public constant slice = ISliceCore(0x21da1b084175f95285B49b22C018889c45E1820d);
    address public constant nouner = 0x008c84421dA5527F462886cEc43D2717B686A7e4;

    AgoraNounsGovernorMock governor;
    address receiver;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_URL_MAINNET"), 18380477);

        address implementation = address(new AgoraNounsGovernorMock());
        receiver = address(new NounsReceiver());

        bytes memory data = abi.encodeCall(AgoraNounsGovernor.initialize, ());
        governor = AgoraNounsGovernorMock(payable(address(new ERC1967Proxy(implementation, data))));
    }

    function testDeploy() public {
        // Assert that the governor is initialized
        assertEq(governor.name(), "Agora Nouns Governor");
        assertEq(address(governor.token()), address(nounsToken));
        assertEq(governor.getDroposalType(0).name, "Standard");
        assertEq(governor.getDroposalType(0).editionSize, 1_000);
        assertEq(governor.getDroposalType(1).name, "Premium");
        assertEq(governor.getDroposalType(1).editionSize, 3_000);
    }

    function testDropose() public {
        vm.prank(nouner);
        governor.dropose(
            DroposalParams({
                droposalType: 0,
                nftType: NFTType.ERC721,
                nftCollection: address(0),
                proposalDescription: "TestProp",
                nftParams: abi.encode(
                    ERC721Params({
                        name: "Test721",
                        symbol: "TST",
                        royaltyBPS: 0,
                        fundsRecipient: payable(address(1)),
                        imageURI: "ipfs://Qm",
                        animationURI: "",
                        description: ""
                    })
                    )
            })
        );
    }

    function testDroposeSepolia() public {
        vm.createSelectFork(vm.envString("RPC_URL_SEPOLIA"), 4548735);

        address implementation = address(new AgoraNounsGovernorSepoliaMock());
        receiver = address(new NounsReceiver());

        bytes memory data = abi.encodeCall(AgoraNounsGovernorSepolia.initialize, ());
        governor = AgoraNounsGovernorMock(payable(address(new ERC1967Proxy(implementation, data))));

        vm.prank(0xEA64B234316728f1BFd3b7cDCc1EAf0066D8E055);
        governor.dropose(
            DroposalParams({
                droposalType: 0,
                nftType: NFTType.ERC721,
                nftCollection: address(0),
                proposalDescription: "TestProp",
                nftParams: abi.encode(
                    ERC721Params({
                        name: "Test721",
                        symbol: "TST",
                        royaltyBPS: 0,
                        fundsRecipient: payable(address(1)),
                        imageURI: "ipfs://Qm",
                        animationURI: "",
                        description: ""
                    })
                    )
            })
        );
    }
}
