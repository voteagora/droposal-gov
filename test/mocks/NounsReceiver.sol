// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract NounsReceiver is ERC1155Receiver {
    address public constant nounsTimelock = 0xf32dd1Bd55bD14d929218499a2E7D106F72f79c7;

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function withdraw(IERC20 token) external {
        token.transfer(nounsTimelock, token.balanceOf(address(this)));
    }

    receive() external payable {
        (bool success,) = nounsTimelock.call{value: msg.value}("");
        require(success);
    }
}
