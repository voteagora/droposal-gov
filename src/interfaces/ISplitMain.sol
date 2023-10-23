// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ISplitMain {
    function createSplit(
        address[] calldata accounts,
        uint32[] calldata percentAllocations,
        uint32 distributorFee,
        address controller
    ) external returns (address payable split);
}
