// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC721Drop} from "zora-721/interfaces/IERC721Drop.sol";

interface IZoraNFTCreator {
    function createEdition(
        string memory name,
        string memory symbol,
        uint64 editionSize,
        uint16 royaltyBPS,
        address payable fundsRecipient,
        address defaultAdmin,
        IERC721Drop.SalesConfiguration memory saleConfig,
        string memory description,
        string memory animationURI,
        string memory imageURI
    ) external returns (address);
}
