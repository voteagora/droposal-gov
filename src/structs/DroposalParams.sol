// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {NFTType, ERC721Params, ERC1155Params, ERC1155TokenParams} from "./NFTParams.sol";

struct DroposalParams {
    /// ID of the droposal type
    uint256 droposalType;
    /// Type of the NFT to be created, ERC721 or ERC1155
    NFTType nftType;
    /// Address of the NFT contract for the drop
    address nftCollection;
    /// Description of the proposal
    string proposalDescription;
    /// Parameters for the NFT contract, encoded as ERC721Params, ERC1155Params or ERC1155TokenParams
    bytes nftParams;
}
