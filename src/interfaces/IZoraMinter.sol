// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {FixedPriceMinter_SalesConfig} from "src/structs/FixedPriceMinter_SalesConfig.sol";

struct SalesConfig {
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

interface IZoraMinter {
    function setSale(uint256 tokenId, FixedPriceMinter_SalesConfig memory salesConfig) external;

    function sale(address tokenContract, uint256 tokenId) external view returns (SalesConfig memory);
}
