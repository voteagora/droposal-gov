// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IERC721Checkpointable {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}
