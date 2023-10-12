// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (governance/extensions/GovernorVotes.sol)

pragma solidity ^0.8.0;

import {GovernorUpgradeableV1, SafeCastUpgradeable} from "./GovernorUpgradeable.sol";
import {
    IERC5805Upgradeable,
    IVotesUpgradeable
} from "@openzeppelin/contracts-upgradeable/interfaces/IERC5805Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * Modifications:
 * - Inherited `GovernorUpgradeableV1`
 */
abstract contract GovernorVotesUpgradeableV1 is Initializable, GovernorUpgradeableV1 {
    IERC5805Upgradeable public token;

    function __GovernorVotes_init(IVotesUpgradeable tokenAddress) internal onlyInitializing {
        __GovernorVotes_init_unchained(tokenAddress);
    }

    function __GovernorVotes_init_unchained(IVotesUpgradeable tokenAddress) internal onlyInitializing {
        token = IERC5805Upgradeable(address(tokenAddress));
    }

    /**
     * @dev Clock (as specified in EIP-6372) is set to match the token's clock. Fallback to block numbers if the token
     * does not implement EIP-6372.
     */
    function clock() public view virtual override returns (uint48) {
        try token.clock() returns (uint48 timepoint) {
            return timepoint;
        } catch {
            return SafeCastUpgradeable.toUint48(block.number);
        }
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override returns (string memory) {
        try token.CLOCK_MODE() returns (string memory clockmode) {
            return clockmode;
        } catch {
            return "mode=blocknumber&from=default";
        }
    }

    /**
     * Read the voting weight from the token's built in snapshot mechanism (see {Governor-_getVotes}).
     */
    function _getVotes(address account, uint256 timepoint, bytes memory /*params*/ )
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return token.getPastVotes(account, timepoint);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
