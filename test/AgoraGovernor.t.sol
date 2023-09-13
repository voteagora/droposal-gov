// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AgoraGovernor.sol";
import "./mocks/MockERC721Drop.sol";

contract AgoraGovernorTest is Test {
    AgoraGovernor governor;
    MockERC721Drop dropFactory;

    function setUp() public {
        governor = new AgoraGovernor();
        dropFactory = new MockERC721Drop();
    }

    function testDropose() public {
        // Define the parameters for dropose
        string memory name = "TestName";
        string memory symbol = "TST";
        uint64 editionSize = 100;
        uint16 royaltyBPS = 10;
        address payable fundsRecipient = payable(address(this));
        address defaultAdmin = address(this);
        uint104 publicSalePrice = 1 ether;
        uint32 maxSalePurchasePerAddress = 5;
        uint64 publicSaleStart = block.timestamp + 1 days;
        uint64 publicSaleEnd = block.timestamp + 10 days;
        uint64 presaleStart = block.timestamp;
        uint64 presaleEnd = block.timestamp + 1 days;
        bytes32 presaleMerkleRoot = 0x0;
        string memory description = "Test Description";
        string memory animationURI = "https://example.com/animation";
        string memory imageURI = "https://example.com/image";
        string memory proposalTitle = "Proposal Test Title";
        string
            memory proposalDescription = "This is a test proposal description";

        // Call the mock dropFactory to create a new edition
        uint256 proposalId = governor.dropose(
            address(dropFactory),
            name,
            symbol,
            editionSize,
            royaltyBPS,
            fundsRecipient,
            defaultAdmin,
            publicSalePrice,
            maxSalePurchasePerAddress,
            publicSaleStart,
            publicSaleEnd,
            presaleStart,
            presaleEnd,
            presaleMerkleRoot,
            description,
            animationURI,
            imageURI,
            proposalTitle,
            proposalDescription
        );

        // Assert that the proposal ID is valid
        assertTrue(proposalId > 0, "Proposal ID should be valid");
    }
}
