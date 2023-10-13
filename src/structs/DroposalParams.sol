// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

enum NFTType {
    ERC721,
    ERC1155
}

struct DroposalParams {
    // Picked by USER
    uint256 droposalType;
    NFTType nftType;
    address nftCollection;
    string name;
    string symbol;
    uint16 royaltyBPS;
    address payable fundsRecipient;
    string imageURI;
    string description;
    string proposalDescription;
}

//
// Derived from droposal Type
// uint64 editionSize;
// uint104 publicSalePrice;
// uint64 publicSaleEnd;
// uint256 splitToArtist;
//
// Default values
// address defaultAdmin; // default to creator
// uint32 maxSalePurchasePerAddress; // default to unlimited
// uint64 publicSaleStart; // Default to droposal end date + 7 days
//
// TBD
// string animationURI; // Default to no animation, empty string ?
// uint64 presaleStart; // Default to no presale?
// uint64 presaleEnd; // Default to no presale?
// bytes32 presaleMerkleRoot; // Default to no presale?
