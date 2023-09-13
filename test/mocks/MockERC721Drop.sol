// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "zora-721-contracts/ERC721Drop.sol";

contract MockERC721Drop is IERC721Drop {

    // Event to help validate that the function was called
    event EditionCreated(string name, string symbol, uint64 editionSize);

    // Simplistic data structure to represent an edition for the sake of the mock
    struct Edition {
        string name;
        string symbol;
        uint64 editionSize;
        uint16 royaltyBPS;
        address payable fundsRecipient;
        address defaultAdmin;
        SalesConfiguration saleConfig;
        string description;
        string animationURI;
        string imageURI;
    }

    Edition[] public editions;

    function createEdition(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        address defaultAdmin,
        SalesConfiguration memory saleConfig,
        string memory description,
        string memory animationURI,
        string memory imageURI
    ) external override {
        // Create a new edition and push it to the editions array
        Edition memory newEdition = Edition({
            name: name,
            symbol: symbol,
            editionSize: editionSize,
            royaltyBPS: royaltyBPS,
            fundsRecipient: fundsRecipient,
            defaultAdmin: defaultAdmin,
            saleConfig: saleConfig,
            description: description,
            animationURI: animationURI,
            imageURI: imageURI
        });

        editions.push(newEdition);

        // Emit an event so you can confirm it was called during testing
        emit EditionCreated(name, symbol, editionSize);
    }

    // If there are other functions in the IERC721Drop interface, mock them similarly.
    // Remember, in a mock, you want to either simulate the real behavior or just have
    // stubs that let you verify function calls during testing.
}
