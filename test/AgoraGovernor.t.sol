// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {AgoraNounsGovernor, AgoraNounsGovernorMock} from "./mocks/AgoraNounsGovernorMock.sol";
import {AgoraNounsGovernorSepolia, AgoraNounsGovernorSepoliaMock} from "./mocks/AgoraNounsGovernorSepoliaMock.sol";
import {NounsReceiver} from "./mocks/NounsReceiver.sol";
import {IERC721Checkpointable} from "src/lib/openzeppelin/v1/GovernorVotesUpgradeable.sol";
import {IGovernorUpgradeable} from "src/lib/openzeppelin/v1/GovernorUpgradeable.sol";
import {IZoraCreator1155Factory} from "src/interfaces/IZoraCreator1155Factory.sol";
import {IZoraCreator1155} from "src/interfaces/IZoraCreator1155.sol";
import {IZoraCreator721} from "src/interfaces/IZoraCreator721.sol";
import {IZoraMinter, SalesConfig} from "src/interfaces/IZoraMinter.sol";
import {ISliceCore, Payee, SliceParams} from "src/interfaces/ISliceCore.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    DroposalParams, NFTType, ERC721Params, ERC1155Params, ERC1155TokenParams
} from "src/structs/DroposalParams.sol";
import {DroposalConfig} from "src/structs/DroposalConfig.sol";

struct RoyaltyConfiguration {
    uint32 royaltyMintSchedule;
    uint32 royaltyBPS;
    address royaltyRecipient;
}

contract AgoraGovernorTest is Test {
    // IZoraCreator721
    event CreatedDrop(address indexed creator, address indexed editionContractAddress, uint256 editionSize);
    // IZoraCreator1155Factory
    event SetupNewContract(
        address indexed newContract,
        address indexed creator,
        address indexed defaultAdmin,
        string contractURI,
        string name,
        RoyaltyConfiguration defaultRoyaltyConfiguration
    );

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
    uint256 droposalType = 0;

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

    function testDropose721() public {
        vm.startPrank(nouner);
        uint64 publicSaleStart = uint64(block.timestamp) + 15 days;
        DroposalConfig memory config = governor.getDroposalType(droposalType);
        DroposalParams memory droposalParams = DroposalParams({
            droposalType: droposalType,
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
        });

        uint256 proposalId = governor.dropose(droposalParams);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            governor.encode721Data(publicSaleStart, droposalParams, config);

        vm.expectEmit();
        emit CreatedDrop({
            creator: address(governor),
            editionSize: config.editionSize,
            editionContractAddress: 0xFF29146F27fc65e82E9c7072c86c40fb3835576D
        });
        governor.forceExecute(proposalId, targets, values, calldatas, keccak256("TestProp"));

        vm.stopPrank();
    }

    function _assertDroposalCreated() internal {}

    function testDropose1155() public {
        vm.startPrank(nouner);

        uint64 publicSaleStart = uint64(block.timestamp) + 15 days;
        DroposalConfig memory config = governor.getDroposalType(droposalType);
        DroposalParams memory droposalParams = DroposalParams({
            droposalType: 0,
            nftType: NFTType.ERC1155,
            nftCollection: address(0),
            proposalDescription: "TestProp",
            nftParams: abi.encode(
                ERC1155Params({
                    name: "Test1155",
                    contractURI: "contractUri",
                    tokenParams: ERC1155TokenParams({royaltyBPS: 0, fundsRecipient: payable(address(1)), tokenURI: ""})
                })
                )
        });

        uint256 proposalId = governor.dropose(droposalParams);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            governor.encode1155Data(publicSaleStart, droposalParams, config);

        vm.expectEmit();
        emit SetupNewContract({
            newContract: 0x1F0f671187C783f8DFaDDE3835683E0D1230AB79,
            creator: address(governor),
            defaultAdmin: nouner,
            contractURI: "contractUri",
            name: "Test1155",
            defaultRoyaltyConfiguration: RoyaltyConfiguration({
                royaltyMintSchedule: 0,
                royaltyBPS: 0,
                royaltyRecipient: nouner
            })
        });
        governor.forceExecute(proposalId, targets, values, calldatas, keccak256("TestProp"));

        assertSalesConfig(0x1F0f671187C783f8DFaDDE3835683E0D1230AB79, 1, config);

        vm.stopPrank();
    }

    function testDroposeExisting1155() public {
        uint256 tokenId = 2;

        address nftCollection = 0xf0f83a794906aE2ca97927AfaBc98d5855b046c7;
        // Add governor the minter permission at `CONTRACT_BASE_ID` = 0
        vm.prank(IZoraCreator1155(nftCollection).owner());
        IZoraCreator1155(nftCollection).addPermission(0, address(governor), 2 ** 2);
        // Add governor the minter permission at `tokenId`
        vm.prank(IZoraCreator1155(nftCollection).owner());
        IZoraCreator1155(nftCollection).addPermission(tokenId, address(governor), 2 ** 2);
        // Add FIXED_PRICE_MINTER the minter permission at `tokenId`
        vm.prank(IZoraCreator1155(nftCollection).owner());
        IZoraCreator1155(nftCollection).addPermission(tokenId, FIXED_PRICE_MINTER, 2 ** 2);

        vm.startPrank(nouner);
        uint64 publicSaleStart = uint64(block.timestamp) + 15 days;
        DroposalConfig memory config = governor.getDroposalType(droposalType);
        DroposalParams memory droposalParams = DroposalParams({
            droposalType: 0,
            nftType: NFTType.ERC1155,
            nftCollection: nftCollection,
            proposalDescription: "TestProp",
            nftParams: abi.encode(
                ERC1155TokenParams({royaltyBPS: 0, fundsRecipient: payable(address(1)), tokenURI: "test"})
                )
        });

        uint256 proposalId = governor.dropose(droposalParams);

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) =
            governor.encodeExisting1155Data(publicSaleStart, droposalParams, config);

        governor.forceExecute(proposalId, targets, values, calldatas, keccak256("TestProp"));

        assertSalesConfig(nftCollection, tokenId, config);

        vm.stopPrank();
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

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function assertSalesConfig(address tokenContract, uint256 tokenId, DroposalConfig memory config) internal {
        SalesConfig memory salesConfig = IZoraMinter(FIXED_PRICE_MINTER).sale(tokenContract, tokenId);

        uint64 publicSaleStart = uint64(block.timestamp) + 15 days;

        assertEq(salesConfig.saleStart, publicSaleStart);
        assertEq(salesConfig.saleEnd, publicSaleStart + config.publicSaleDuration);
        assertEq(salesConfig.maxTokensPerAddress, 0);
        assertEq(salesConfig.pricePerToken, config.publicSalePrice);
        assertEq(salesConfig.fundsRecipient, address(AgoraNounsGovernorMock(governor.fundsRecipient())));
    }
}
