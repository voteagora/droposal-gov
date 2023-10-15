// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {RoyaltyConfiguration} from "./IZoraCreator1155.sol";

/// @notice Factory for 1155 contracts
/// @author @iainnash / @tbtstl

interface IZoraCreator1155Factory {
    function createContract(
        string memory contractURI,
        string calldata name,
        RoyaltyConfiguration memory defaultRoyaltyConfiguration,
        address payable defaultAdmin,
        bytes[] calldata setupActions
    ) external returns (address);

    /// @notice creates the contract, using a deterministic address based on the name, contract uri, and defaultAdmin
    function createContractDeterministic(
        string calldata contractURI,
        string calldata name,
        RoyaltyConfiguration calldata defaultRoyaltyConfiguration,
        address payable defaultAdmin,
        bytes[] calldata setupActions
    ) external returns (address);

    function deterministicContractAddress(
        address msgSender,
        string calldata newContractURI,
        string calldata name,
        address contractAdmin
    ) external view returns (address);

    function defaultMinters() external returns (address[] memory minters);

    function initialize(address _owner) external;
}
