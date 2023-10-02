// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {
    GovernorUpgradeable,
    IGovernorUpgradeable
} from "openzeppelin-contracts-upgradeable/governance/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeable} from
    "openzeppelin-contracts-upgradeable/governance/extensions/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from
    "openzeppelin-contracts-upgradeable/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {
    GovernorVotesUpgradeable,
    IVotesUpgradeable
} from "openzeppelin-contracts-upgradeable/governance/extensions/GovernorVotesUpgradeable.sol";
import {GovernorVotesQuorumFractionUpgradeable} from
    "openzeppelin-contracts-upgradeable/governance/extensions/GovernorVotesQuorumFractionUpgradeable.sol";
import {
    GovernorTimelockControlUpgradeable,
    TimelockControllerUpgradeable
} from "openzeppelin-contracts-upgradeable/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ZoraNFTCreatorV1} from "zora-1155-contracts/ZoraNFTCreatorV1.sol";
import {IERC721Drop} from "zora-1155-contracts/interfaces/IERC721Drop.sol";

/// @custom:security-contact kent@voteagora.com
contract AgoraGovernor is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorVotesQuorumFractionUpgradeable,
    GovernorTimelockControlUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    mapping(uint256 => address) private _proposers;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IVotesUpgradeable _token, TimelockControllerUpgradeable _timelock) public initializer {
        __Governor_init("Agora Nouns Governor");
        __GovernorSettings_init(7200, /* 1 day */ 50400, /* 1 week */ 0);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(_token);
        __GovernorVotesQuorumFraction_init(4);
        __GovernorTimelockControl_init(_timelock);
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // The following functions are overrides required by Solidity.

    function votingDelay() public view override(IGovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingDelay();
    }

    function votingPeriod() public view override(IGovernorUpgradeable, GovernorSettingsUpgradeable) returns (uint256) {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernorUpgradeable, GovernorVotesQuorumFractionUpgradeable)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override(GovernorUpgradeable, IGovernorUpgradeable) returns (uint256) {
        uint256 proposalId = super.propose(targets, values, calldatas, description);
        // Store the address of the proposer for this proposalId
        _proposers[proposalId] = _msgSender();
        return proposalId;
    }

    struct DroposeParams {
        address dropFactory;
        string name;
        string symbol;
        uint64 editionSize;
        uint16 royaltyBPS;
        address payable fundsRecipient;
        address defaultAdmin;
        uint104 publicSalePrice;
        uint32 maxSalePurchasePerAddress;
        uint64 publicSaleStart;
        uint64 publicSaleEnd;
        uint64 presaleStart;
        uint64 presaleEnd;
        bytes32 presaleMerkleRoot;
        string description;
        string animationURI;
        string imageURI;
        string proposalTitle;
        string proposalDescription;
    }

    function dropose(DroposeParams memory params) public returns (uint256) {
        IERC721Drop.SalesConfiguration memory saleConfig = IERC721Drop.SalesConfiguration({
            publicSalePrice: params.publicSalePrice,
            maxSalePurchasePerAddress: params.maxSalePurchasePerAddress,
            publicSaleStart: params.publicSaleStart,
            publicSaleEnd: params.publicSaleEnd,
            presaleStart: params.presaleStart,
            presaleEnd: params.presaleEnd,
            presaleMerkleRoot: params.presaleMerkleRoot
        });

        bytes memory callData = abi.encodeWithSelector(
            ZoraNFTCreatorV1(params.dropFactory).createEdition.selector,
            params.name,
            params.symbol,
            params.editionSize,
            params.royaltyBPS,
            params.fundsRecipient,
            params.defaultAdmin,
            saleConfig,
            params.description,
            params.animationURI,
            params.imageURI
        );

        string memory fullProposalDescription =
            string(abi.encodePacked(params.proposalTitle, "##", params.proposalDescription));

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = params.dropFactory;
        values[0] = 0;
        calldatas[0] = callData;

        return propose(targets, values, calldatas, fullProposalDescription);
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    // Get the proposer of a proposal
    function getProposer(uint256 proposalId) external view returns (address) {
        return _proposers[proposalId];
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(GovernorUpgradeable, IGovernorUpgradeable) returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        // Fetch the proposer for the given proposalId
        address proposer = _proposers[proposalId];

        // Ensure that only the original proposer can execute this proposal
        require(proposer == _msgSender(), "AgoraGovernor: Only the proposer can execute this proposal");

        // Call the original execute logic
        return super.execute(targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(GovernorUpgradeable, GovernorTimelockControlUpgradeable) {
        return super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
