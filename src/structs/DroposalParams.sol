// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

struct FixedPriceMinter_SalesConfig {
    /// @notice Unix timestamp for the sale start
    uint64 saleStart;
    /// @notice Unix timestamp for the sale end
    uint64 saleEnd;
    /// @notice Max tokens that can be minted for an address, 0 if unlimited
    uint64 maxTokensPerAddress;
    /// @notice Price per token in eth wei
    uint96 pricePerToken;
    /// @notice Funds recipient (0 if no different funds recipient than the contract global)
    address fundsRecipient;
}

enum NFTType {
    ERC721,
    ERC1155
}

struct ERC721Params {
    string name;
    string symbol;
    uint16 royaltyBPS;
    address payable fundsRecipient;
    string imageURI;
    string description;
}

struct ERC1155Params {
    string name;
    string contractURI;
    ERC1155TokenParams tokenParams;
}

struct ERC1155TokenParams {
    uint16 royaltyBPS;
    address payable fundsRecipient;
    string tokenURI;
}

struct DroposalParams {
    // Picked by USER
    uint256 droposalType;
    NFTType nftType;
    address nftCollection;
    string proposalDescription;
    bytes nftParams;
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
