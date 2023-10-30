// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AgoraNounsGovernorSepolia} from "./AgoraNounsGovernorSepolia.sol";
import {
    DroposalParams, NFTType, ERC721Params, ERC1155Params, ERC1155TokenParams
} from "src/structs/DroposalParams.sol";
import {DroposalConfig} from "src/structs/DroposalConfig.sol";

contract AgoraNounsGovernorSepoliaMock is AgoraNounsGovernorSepolia {
    function getDroposalType(uint256 droposalTypeId) public view returns (DroposalConfig memory) {
        return droposalTypes[droposalTypeId];
    }

    function getPendingDroposalType(uint256 droposalTypeId) public view returns (DroposalConfig memory) {
        return pendingDroposalTypes[droposalTypeId];
    }

    function getCurrentPendingDroposalCount() public view returns (uint256) {
        return currentPendingDroposalCount;
    }

    function encode721Data(uint64 publicSaleStart, DroposalParams memory droposalParams, DroposalConfig memory config)
        public
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        return _encode721Data(publicSaleStart, droposalParams, config);
    }

    function encode1155Data(uint64 publicSaleStart, DroposalParams memory droposalParams, DroposalConfig memory config)
        public
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        return _encode1155Data(publicSaleStart, droposalParams, config);
    }

    function encodeExisting1155Data(
        uint64 publicSaleStart,
        DroposalParams memory droposalParams,
        DroposalConfig memory config
    ) public view returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
        return _encodeExisting1155Data(publicSaleStart, droposalParams, config);
    }

    function createSlice(address recipient, uint32 split) public returns (address) {
        return _createSplitSlice(recipient, split);
    }
}
