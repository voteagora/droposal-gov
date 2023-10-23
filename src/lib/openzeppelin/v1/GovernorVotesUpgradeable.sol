// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import {GovernorUpgradeableV1} from "./GovernorUpgradeable.sol";
import {IERC721Checkpointable} from "src/interfaces/IERC721Checkpointable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * Modifications:
 * - Inherited `GovernorUpgradeableV1`
 * - Change _getVotes to support nouns
 */
abstract contract GovernorVotesUpgradeableV1 is Initializable, GovernorUpgradeableV1 {
    IERC721Checkpointable public token;

    function __GovernorVotes_init(IERC721Checkpointable tokenAddress) internal onlyInitializing {
        __GovernorVotes_init_unchained(tokenAddress);
    }

    function __GovernorVotes_init_unchained(IERC721Checkpointable tokenAddress) internal onlyInitializing {
        token = tokenAddress;
    }

    /**
     * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
     */
    function _getVotes(address account, uint256 blockNumber, bytes memory /*params*/ )
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return token.getPriorVotes(account, blockNumber);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
