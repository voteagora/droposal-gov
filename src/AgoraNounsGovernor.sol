// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {GovernorUpgradeableV1, IGovernorUpgradeable} from "src/lib/openzeppelin/v1/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeableV1, IVotesUpgradeable} from "src/lib/openzeppelin/v1/GovernorVotesUpgradeable.sol";
import {IZoraNFTCreator, IERC721Drop} from "src/interfaces/IZoraNFTCreator.sol";
import {DroposalConfig} from "src/structs/DroposalConfig.sol";
import {DroposalParams, NFTType} from "src/structs/DroposalParams.sol";

// TODO:
// - Ask zora about how to set the splits
// - Should we draft droposalTypes offchain? Any reason why we may want to do it onchain?

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
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event DroposalTypeSet(uint256 droposalType, DroposalConfig config, string droposalTypeName);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyProposer();
    error OnlyDroposals();
    error InvalidDroposalType();

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    // TODO: Add addresses
    IGovernorUpgradeable public constant nounsGovernor = IGovernorUpgradeable(address(1));
    address public constant zoraNFTCreator = address(2);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 droposalTypeId => DroposalConfig) public droposalTypes;

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

        // TODO: Init droposalTypes
        _setDroposalType(
            0, DroposalConfig({editionSize: 0, publicSalePrice: 0, publicSaleDuration: 0, splitToArtist: 0}), "Standard"
        );
        _setDroposalType(
            1, DroposalConfig({editionSize: 0, publicSalePrice: 0, publicSaleDuration: 0, splitToArtist: 0}), "Premium"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            WRITE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// Format proposal for a drop
    function dropose(DroposalParams memory params) public returns (uint256) {
        DroposalConfig memory config = droposalTypes[params.droposalType];

        if (config.editionSize == 0) revert InvalidDroposalType();

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        // 1 day (pending) + 7 days (voting) + 7 days (after approval)
        uint256 publicSaleStart = block.timestamp + 15 days;

        if (params.nftType == NFTType.ERC721) {
            (targets, calldatas) = _encode721Data(publicSaleStart, params, config, targets, calldatas);
        } else {
            if (params.nftCollection == address(0)) {
                (targets, calldatas) = _encode1155Data(publicSaleStart, params, config, targets, calldatas);
            } else {
                (targets, calldatas) = _encodeExisting1155Data(publicSaleStart, params, config, targets, calldatas);
            }
        }

        return super.propose(targets, values, calldatas, params.proposalDescription);
    }

    /// Disabled to only allow droposals
    function propose(
        address[] memory, /* targets */
        uint256[] memory, /* values */
        bytes[] memory, /* calldatas */
        string memory /* description */
    ) public pure override returns (uint256) {
        revert OnlyDroposals();
    }

    /*//////////////////////////////////////////////////////////////
                               RESTRICTED
    //////////////////////////////////////////////////////////////*/

    function setDroposalType(uint256 droposalTypeId, DroposalConfig memory config, string memory droposalTypeName)
        public
        onlyOwner
    {
        _setDroposalType(droposalTypeId, config, droposalTypeName);
    }

    function _setDroposalType(uint256 droposalTypeId, DroposalConfig memory config, string memory droposalTypeName)
        internal
    {
        droposalTypes[droposalTypeId] = config;
        emit DroposalTypeSet(droposalTypeId, config, droposalTypeName);
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// Getter for proposals
    function proposals(uint256 proposalId) public view returns (ProposalCore memory proposal) {
        return _proposals[proposalId];
    }

    /// Inherit quorum from the main Nouns governor
    function quorum(uint256 blockNumber) public view override returns (uint256) {
        return nounsGovernor.quorum(blockNumber);
    }

    /// Inherit quorum from the main Nouns governor
    /// @dev Increment to account for different revert condition in propose
    // TODO: Test
    function proposalThreshold()
        public
        view
        override(GovernorUpgradeableV1, GovernorSettingsUpgradeableV1)
        returns (uint256)
    {
        unchecked {
            return GovernorUpgradeableV1(payable(address(nounsGovernor))).proposalThreshold() + 1;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    function _encode721Data(
        uint256 publicSaleStart,
        DroposalParams memory params,
        DroposalConfig memory config,
        address[] memory targets,
        bytes[] memory calldatas
    ) internal view returns (address[] memory, bytes[] memory) {
        targets[0] = zoraNFTCreator;
        calldatas[0] = abi.encodeCall(
            IZoraNFTCreator.createEdition,
            (
                params.name,
                params.symbol,
                config.editionSize,
                params.royaltyBPS,
                params.fundsRecipient,
                msg.sender,
                IERC721Drop.SalesConfiguration({
                    publicSalePrice: config.publicSalePrice,
                    maxSalePurchasePerAddress: 0,
                    publicSaleStart: uint64(publicSaleStart),
                    publicSaleEnd: uint64(publicSaleStart) + config.publicSaleDuration,
                    presaleStart: 0,
                    presaleEnd: 0,
                    presaleMerkleRoot: 0
                }),
                params.description,
                "",
                params.imageURI
            )
        );

        return (targets, calldatas);
    }

    function _encode1155Data(
        uint256 publicSaleStart,
        DroposalParams memory params,
        DroposalConfig memory config,
        address[] memory targets,
        bytes[] memory calldatas
    ) internal view returns (address[] memory, bytes[] memory) {
        targets[0] = zoraNFTCreator;
        calldatas[0] = abi.encodeCall(
            IZoraNFTCreator.createEdition,
            (
                params.name,
                params.symbol,
                config.editionSize,
                params.royaltyBPS,
                params.fundsRecipient,
                msg.sender,
                IERC721Drop.SalesConfiguration({
                    publicSalePrice: config.publicSalePrice,
                    maxSalePurchasePerAddress: 0,
                    publicSaleStart: uint64(publicSaleStart),
                    publicSaleEnd: uint64(publicSaleStart) + config.publicSaleDuration,
                    presaleStart: 0,
                    presaleEnd: 0,
                    presaleMerkleRoot: 0
                }),
                params.description,
                "",
                params.imageURI
            )
        );

        return (targets, calldatas);
    }

    function _encodeExisting1155Data(
        uint256 publicSaleStart,
        DroposalParams memory params,
        DroposalConfig memory config,
        address[] memory targets,
        bytes[] memory calldatas
    ) internal view returns (address[] memory, bytes[] memory) {
        targets[0] = zoraNFTCreator;
        calldatas[0] = abi.encodeCall(
            IZoraNFTCreator.createEdition,
            (
                params.name,
                params.symbol,
                config.editionSize,
                params.royaltyBPS,
                params.fundsRecipient,
                msg.sender,
                IERC721Drop.SalesConfiguration({
                    publicSalePrice: config.publicSalePrice,
                    maxSalePurchasePerAddress: 0,
                    publicSaleStart: uint64(publicSaleStart),
                    publicSaleEnd: uint64(publicSaleStart) + config.publicSaleDuration,
                    presaleStart: 0,
                    presaleEnd: 0,
                    presaleMerkleRoot: 0
                }),
                params.description,
                "",
                params.imageURI
            )
        );

        return (targets, calldatas);
    }

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
}
