// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {GovernorUpgradeableV1, IGovernorUpgradeable} from "src/lib/openzeppelin/v1/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeableV1, IVotesUpgradeable} from "src/lib/openzeppelin/v1/GovernorVotesUpgradeable.sol";
import {IZoraCreator721, IERC721Drop} from "src/interfaces/IZoraCreator721.sol";
import {IZoraCreator1155, RoyaltyConfiguration} from "src/interfaces/IZoraCreator1155.sol";
import {IZoraCreator1155Factory} from "src/interfaces/IZoraCreator1155Factory.sol";
import {DroposalConfig} from "src/structs/DroposalConfig.sol";
import {
    DroposalParams,
    NFTType,
    ERC721Params,
    ERC1155Params,
    ERC1155TokenParams,
    FixedPriceMinter_SalesConfig
} from "src/structs/DroposalParams.sol";

// TODO:
// - Set initial droposal types
// - Set addresses for nounsGovernor and zora contracts
// - Test inherited proposalThreshold
// --------------
// Questions:
// - [Agora] Are the init params set up as intended?
// - [Agora] Should we draft droposalTypes offchain? Any reason why we may want to do it onchain?
// - [zora] How should splits be set up (ie 40% artist, 60% DAO)
// - [zora] Check if create edition / mint logic is correct

// Features:
// - `dropose`: Format proposal for a drop, either new ERC721, new ERC1155, or existing ERC1155
// - `proposeDroposalType`: Propose a new droposal type to be approved by contract owner
// - `setDroposalType`: Allows owner to set a droposal types.
// - `approveDroposalType`: Allows owner to approve a pending droposal type.
// - Allow only proposer to execute.
// - Inherit quorum and proposalThreshold from main Nouns governor.

/// @title Agora Nouns Governor
/// @notice A governor implementation to handle the creation of droposals
/// @author jacopo@dlabs.app
/// @author kent@voteagora.com
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

    event DroposalTypeSet(uint256 droposalTypeId, DroposalConfig config);
    event DroposalTypeProposed(uint256 droposalTypeId, DroposalConfig config);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyProposer();
    error OnlyDroposals();
    error InvalidDroposalType();

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    IGovernorUpgradeable public constant nounsGovernor = IGovernorUpgradeable(address(1));
    address public constant zoraNFTCreator721 = address(2);
    IZoraCreator1155Factory public constant zoraNFTCreator1155 = IZoraCreator1155Factory(address(3));
    address public constant FIXED_PRICE_MINTER = address(4);

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 droposalTypeId => DroposalConfig) public droposalTypes;

    mapping(uint256 pendingDroposalTypeId => DroposalConfig) public pendingDroposalTypes;
    uint256 public currentDroposalTypeId;

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

        _setDroposalType(
            0,
            DroposalConfig({
                name: "Standard",
                editionSize: 0,
                publicSalePrice: 0,
                publicSaleDuration: 0,
                splitToArtist: 0,
                minter: FIXED_PRICE_MINTER
            })
        );
        _setDroposalType(
            1,
            DroposalConfig({
                name: "Premium",
                editionSize: 3_000,
                publicSalePrice: 0.069 ether,
                publicSaleDuration: 3 days,
                splitToArtist: 0,
                minter: FIXED_PRICE_MINTER
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                                DROPOSE
    //////////////////////////////////////////////////////////////*/

    /// Format proposal for a drop.
    /// For existing erc1155, AgoraNounsGovernor has to have admin rights for the token being created.
    function dropose(DroposalParams memory droposalParams) public returns (uint256) {
        DroposalConfig memory config = droposalTypes[droposalParams.droposalType];

        if (config.editionSize == 0) revert InvalidDroposalType();

        // 1 day (pending) + 7 days (voting) + 7 days (after approval)
        uint64 publicSaleStart = uint64(block.timestamp) + 15 days;

        address[] memory targets;
        uint256[] memory values;
        bytes[] memory calldatas;

        if (droposalParams.nftType == NFTType.ERC721) {
            (targets, values, calldatas) = _encode721Data(publicSaleStart, droposalParams, config);
        } else {
            if (droposalParams.nftCollection == address(0)) {
                (targets, values, calldatas) = _encode1155Data(publicSaleStart, droposalParams, config);
            } else {
                (targets, values, calldatas) = _encodeExisting1155Data(publicSaleStart, droposalParams, config);
            }
        }

        return super.propose(targets, values, calldatas, droposalParams.proposalDescription);
    }

    function _encode721Data(uint64 publicSaleStart, DroposalParams memory droposalParams, DroposalConfig memory config)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        (ERC721Params memory params) = abi.decode(droposalParams.nftParams, (ERC721Params));

        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        targets[0] = zoraNFTCreator721;
        calldatas[0] = abi.encodeCall(
            IZoraCreator721.createEditionWithReferral,
            (
                params.name,
                params.symbol,
                config.editionSize,
                params.royaltyBPS,
                params.fundsRecipient,
                msg.sender, // defaultAdmin
                IERC721Drop.SalesConfiguration({
                    publicSalePrice: config.publicSalePrice,
                    maxSalePurchasePerAddress: 0,
                    publicSaleStart: publicSaleStart,
                    publicSaleEnd: publicSaleStart + config.publicSaleDuration,
                    presaleStart: 0,
                    presaleEnd: 0,
                    presaleMerkleRoot: 0
                }),
                params.description,
                "", // animationURI
                params.imageURI,
                address(0) // createReferral
            )
        );
    }

    function _encode1155Data(uint64 publicSaleStart, DroposalParams memory droposalParams, DroposalConfig memory config)
        internal
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas)
    {
        (ERC1155Params memory params) = abi.decode(droposalParams.nftParams, (ERC1155Params));

        targets = new address[](1);
        values = new uint256[](1);
        calldatas = new bytes[](1);

        bytes memory minterData = abi.encode(
            FixedPriceMinter_SalesConfig({
                saleStart: publicSaleStart,
                saleEnd: publicSaleStart + config.publicSaleDuration,
                maxTokensPerAddress: 0,
                pricePerToken: config.publicSalePrice,
                fundsRecipient: params.tokenParams.fundsRecipient
            })
        );

        bytes[] memory setupActions = new bytes[](3);
        // setupNewToken
        setupActions[0] = abi.encodeCall(
            IZoraCreator1155.setupNewToken,
            (
                params.tokenParams.tokenURI,
                config.editionSize // maxSupply TODO: check
            )
        );
        // callSale
        setupActions[1] = abi.encodeCall(IZoraCreator1155.callSale, (1, config.minter, minterData));
        // updateRoyaltiesForToken
        setupActions[2] = abi.encodeCall(
            IZoraCreator1155.updateRoyaltiesForToken, (1, _royaltyConfiguration(params.tokenParams.royaltyBPS))
        );

        // createContract
        targets[0] = address(zoraNFTCreator1155);
        calldatas[0] = abi.encodeCall(
            IZoraCreator1155Factory.createContract,
            (
                params.contractURI,
                params.name,
                _royaltyConfiguration(params.tokenParams.royaltyBPS),
                payable(msg.sender), // defaultAdmin TODO: check
                setupActions
            )
        );

        // TODO: Set splits
    }

    function _encodeExisting1155Data(
        uint64 publicSaleStart,
        DroposalParams memory droposalParams,
        DroposalConfig memory config
    ) internal view returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
        (ERC1155TokenParams memory params) = abi.decode(droposalParams.nftParams, (ERC1155TokenParams));

        targets = new address[](3);
        values = new uint256[](3);
        calldatas = new bytes[](3);

        bytes memory minterData = abi.encode(
            FixedPriceMinter_SalesConfig({
                saleStart: publicSaleStart,
                saleEnd: publicSaleStart + config.publicSaleDuration,
                maxTokensPerAddress: 0,
                pricePerToken: config.publicSalePrice,
                fundsRecipient: params.fundsRecipient
            })
        );
        uint256 tokenId = IZoraCreator1155(droposalParams.nftCollection).nextTokenId();

        // setupNewToken
        targets[0] = droposalParams.nftCollection;
        calldatas[0] = abi.encodeCall(
            IZoraCreator1155.setupNewToken,
            (
                params.tokenURI,
                config.editionSize // maxSupply
            )
        );

        // callSale
        targets[1] = droposalParams.nftCollection;
        calldatas[1] = abi.encodeCall(IZoraCreator1155.callSale, (tokenId, config.minter, minterData));

        // updateRoyaltiesForToken
        targets[2] = droposalParams.nftCollection;
        calldatas[2] = abi.encodeCall(
            IZoraCreator1155.updateRoyaltiesForToken, (tokenId, _royaltyConfiguration(params.royaltyBPS))
        );

        // TODO: Set splits
    }

    // TODO: Check
    function _royaltyConfiguration(uint256 royaltyBPS) internal view returns (RoyaltyConfiguration memory) {
        return
            RoyaltyConfiguration({royaltyMintSchedule: 0, royaltyBPS: uint32(royaltyBPS), royaltyRecipient: msg.sender});
    }

    /*//////////////////////////////////////////////////////////////
                             DROPOSAL TYPES
    //////////////////////////////////////////////////////////////*/

    /// Propose a new droposal type to be approved by contract owner.
    function proposeDroposalType(DroposalConfig memory config) public {
        uint256 pendingDroposalTypeId = ++currentDroposalTypeId;

        pendingDroposalTypes[pendingDroposalTypeId] = config;
        emit DroposalTypeProposed(pendingDroposalTypeId, config);
    }

    /// Approve a pending droposal type.
    /// @dev Only owner
    function approveDroposalType(uint256 droposalTypeId, uint256 pendingDroposalTypeId) public onlyOwner {
        if (
            droposalTypes[droposalTypeId].editionSize != 0
                || pendingDroposalTypes[pendingDroposalTypeId].editionSize == 0
        ) revert InvalidDroposalType();
        _setDroposalType(droposalTypeId, pendingDroposalTypes[pendingDroposalTypeId]);
    }

    /// Set `config` for a `droposalTypeId`.
    /// @dev Only owner
    function setDroposalType(uint256 droposalTypeId, DroposalConfig memory config) public onlyOwner {
        _setDroposalType(droposalTypeId, config);
    }

    function _setDroposalType(uint256 droposalTypeId, DroposalConfig memory config) internal {
        droposalTypes[droposalTypeId] = config;
        emit DroposalTypeSet(droposalTypeId, config);
    }

    /*//////////////////////////////////////////////////////////////
                               NOUNS GOV
    //////////////////////////////////////////////////////////////*/

    /// Inherit quorum from the main Nouns governor.
    function quorum(uint256 blockNumber) public view override returns (uint256) {
        return nounsGovernor.quorum(blockNumber);
    }

    /// Inherit proposalThreshold from the main Nouns governor.
    /// @dev Increment to account for different revert condition in propose
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
                                 OTHER
    //////////////////////////////////////////////////////////////*/

    /// Getter for proposals.
    function proposals(uint256 proposalId) public view returns (ProposalCore memory proposal) {
        return _proposals[proposalId];
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

    /// @dev Add requirement that only the proposer can execute.
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
