// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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
    string animationURI;
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
