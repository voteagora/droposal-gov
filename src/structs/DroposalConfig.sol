// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

struct DroposalConfig {
    string name;
    uint64 editionSize;
    uint96 publicSalePrice;
    uint64 publicSaleDuration;
    uint256 splitToArtist; // TODO:
    address minter; // TODO: is it always the same, or should be derived from config?
}
