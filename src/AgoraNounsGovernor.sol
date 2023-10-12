// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {GovernorUpgradeableV1, IGovernorUpgradeable} from "src/lib/openzeppelin/v1/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeableV1, IVotesUpgradeable} from "src/lib/openzeppelin/v1/GovernorVotesUpgradeable.sol";
// import {ZoraNFTCreatorV1} from "zora-721/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "zora-721/interfaces/IERC721Drop.sol";

// TODO:
// - Confirm: NO TIMELOCK?
// - Currently inheriting quorum and proposalThreshold of nouns. Lmk if I should inherit more
// - Do we wanna have same proposalThreshold, votingPeriod, votingDelay as Nouns? Or should we allow modifying them based on governance?
// - Should upgrades be doable by us, or by governance like on nouns?

/// @title Agora Nouns Governor
/// @notice A governor implementation to handle the creation of droposals
/// @author kent@voteagora.com
/// @author jacopo
contract AgoraNounsGovernor is
    UUPSUpgradeable,
    OwnableUpgradeable,
    GovernorUpgradeableV1,
    GovernorSettingsUpgradeableV1,
    GovernorCountingSimpleUpgradeableV1,
    GovernorVotesUpgradeableV1
{
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyProposer();

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    // TODO: Add address
    IGovernorUpgradeable public constant nounsGovernor = IGovernorUpgradeable(address(1));

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyProposer(uint256 proposalId) {
        if (_proposals[proposalId].proposer != _msgSender()) revert OnlyProposer();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IVotesUpgradeable nounsToken) public initializer {
        __Governor_init("Agora Nouns Governor");
        __GovernorSettings_init(7200, /* 1 day */ 50400, /* 1 week */ 0);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(nounsToken);
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Inherit quorum from the main Nouns governor
    function quorum(uint256 blockNumber) public view override returns (uint256) {
        return nounsGovernor.quorum(blockNumber);
    }

    // Getter for proposals
    function proposals(uint256 proposalId) public view returns (ProposalCore memory proposal) {
        return _proposals[proposalId];
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeableV1, GovernorSettingsUpgradeableV1)
        returns (uint256)
    {
        return GovernorUpgradeableV1(payable(address(nounsGovernor))).proposalThreshold();
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Add requirement that only the proposer can execute
    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal virtual override onlyProposer(proposalId) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //     // TODO: Disable to only allow droposals? YES
    //     function propose(
    //         address[] memory targets,
    //         uint256[] memory values,
    //         bytes[] memory calldatas,
    //         string memory description
    //     ) public override(GovernorUpgradeable, IGovernorUpgradeable) returns (uint256) {
    //         uint256 proposalId = super.propose(targets, values, calldatas, description);
    //         // Store the address of the proposer for this proposalId
    //         _proposers[proposalId] = _msgSender();
    //         return proposalId;
    //     }

    //     struct DroposeParams {
    //         address dropFactory;
    //         string name;
    //         string symbol;
    //         uint64 editionSize;
    //         uint16 royaltyBPS;
    //         address payable fundsRecipient;
    //         address defaultAdmin;
    //         uint104 publicSalePrice;
    //         uint32 maxSalePurchasePerAddress;
    //         uint64 publicSaleStart;
    //         uint64 publicSaleEnd;
    //         uint64 presaleStart;
    //         uint64 presaleEnd;
    //         bytes32 presaleMerkleRoot;
    //         string description;
    //         string animationURI;
    //         string imageURI;
    //         string proposalTitle;
    //         string proposalDescription;
    //     }

    //     function dropose(DroposeParams memory params) public returns (uint256) {
    //         IERC721Drop.SalesConfiguration memory saleConfig = IERC721Drop.SalesConfiguration({
    //             publicSalePrice: params.publicSalePrice,
    //             maxSalePurchasePerAddress: params.maxSalePurchasePerAddress,
    //             publicSaleStart: params.publicSaleStart,
    //             publicSaleEnd: params.publicSaleEnd,
    //             presaleStart: params.presaleStart,
    //             presaleEnd: params.presaleEnd,
    //             presaleMerkleRoot: params.presaleMerkleRoot
    //         });

    //         bytes memory callData = abi.encodeWithSelector(
    //             ZoraNFTCreatorV1(params.dropFactory).createEdition.selector,
    //             params.name,
    //             params.symbol,
    //             params.editionSize,
    //             params.royaltyBPS,
    //             params.fundsRecipient,
    //             params.defaultAdmin,
    //             saleConfig,
    //             params.description,
    //             params.animationURI,
    //             params.imageURI
    //         );

    //         string memory fullProposalDescription =
    //             string(abi.encodePacked(params.proposalTitle, "##", params.proposalDescription));

    //         address[] memory targets = new address[](1);
    //         uint256[] memory values = new uint256[](1);
    //         bytes[] memory calldatas = new bytes[](1);

    //         targets[0] = params.dropFactory;
    //         values[0] = 0;
    //         calldatas[0] = callData;

    //         return propose(targets, values, calldatas, fullProposalDescription);
    //     }
}
