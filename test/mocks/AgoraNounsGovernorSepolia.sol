// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {GovernorUpgradeableV1, IGovernorUpgradeable} from "src/lib/openzeppelin/v1/GovernorUpgradeable.sol";
import {GovernorSettingsUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorSettingsUpgradeable.sol";
import {GovernorCountingSimpleUpgradeableV1} from "src/lib/openzeppelin/v1/GovernorCountingSimpleUpgradeable.sol";
import {GovernorVotesUpgradeableV1, IERC721Checkpointable} from "src/lib/openzeppelin/v1/GovernorVotesUpgradeable.sol";
import {IZoraCreator721, IERC721Drop} from "src/interfaces/IZoraCreator721.sol";
import {IZoraCreator1155, RoyaltyConfiguration} from "src/interfaces/IZoraCreator1155.sol";
import {IZoraCreator1155Factory} from "src/interfaces/IZoraCreator1155Factory.sol";
import {IZoraMinter} from "src/interfaces/IZoraMinter.sol";
import {ISliceCore, Payee, SliceParams} from "src/interfaces/ISliceCore.sol";
import {ISplitMain} from "src/interfaces/ISplitMain.sol";
import {
    DroposalParams, NFTType, ERC721Params, ERC1155Params, ERC1155TokenParams
} from "src/structs/DroposalParams.sol";
import {DroposalConfig} from "src/structs/DroposalConfig.sol";
import {FixedPriceMinter_SalesConfig} from "src/structs/FixedPriceMinter_SalesConfig.sol";

// Updated contract addresses
// Disabled splits

/**
 * @title Agora Nouns Governor
 * @notice Governor to handle the creation of droposals.
 *
 * Features:
 * - `dropose`: Format proposal for a drop, either new ERC721, new ERC1155, or existing ERC1155
 * - `proposeDroposalType`: Propose a new droposal type to be approved by contract owner
 * - `setDroposalType`: Allows owner to set a droposal types.
 * - `approveDroposalType`: Allows owner to approve a pending droposal type.
 * - Allow only proposer to execute.
 * - Inherit quorum and proposalThreshold from main Nouns governor.
 */
contract AgoraNounsGovernorSepolia is
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
    event DroposalTypeApproved(uint256 droposalTypeId);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyProposer();
    error OnlyDroposals();
    error InvalidDroposalType();

    /*//////////////////////////////////////////////////////////////
                           IMMUTABLE STORAGE
    //////////////////////////////////////////////////////////////*/

    IERC721Checkpointable public constant nounsToken = IERC721Checkpointable(0x05d570185F6e2d29AdaBa1F36435f50Bc44A6f17);
    IGovernorUpgradeable public constant nounsGovernor =
        IGovernorUpgradeable(0x461208f0073e3b1C9Cec568DF2fcACD0700C9B7a);
    address public constant nounsReceiver = 0x2e234DAe75C793f67A35089C9d99245E1C58470b; // unused
    address public constant zoraNFTCreator721 = 0x87cfd516c5ea86e50b950678CA970a8a28de27ac;
    IZoraCreator1155Factory public constant zoraCreator1155Factory =
        IZoraCreator1155Factory(0x13dAA8E9e3f68deDE7b1386ACdc12eA98F2FB688);
    address public constant FIXED_PRICE_MINTER = 0xA5E8d0d4FCed34E86AF6d4E16131C7210Ba8b4b7;
    ISliceCore public constant slice = ISliceCore(0x21da1b084175f95285B49b22C018889c45E1820d); // unused
    ISplitMain public constant splitMain = ISplitMain(0x2ed6c4B5dA6378c7897AC67Ba9e43102Feb694EE); // unused

    uint32 private constant SPLIT_PERCENTAGE_SCALE = 1e6;

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 droposalTypeId => DroposalConfig) public droposalTypes;

    mapping(uint256 pendingDroposalTypeId => DroposalConfig) public pendingDroposalTypes;
    uint256 public pendingDroposalTypesCount;

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

    function initialize() public initializer {
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
                editionSize: 1_000,
                publicSalePrice: 0.03 ether,
                publicSaleDuration: 3 days,
                fundsRecipientSplit: 400_000,
                minter: FIXED_PRICE_MINTER
            })
        );
        _setDroposalType(
            1,
            DroposalConfig({
                name: "Premium",
                editionSize: 3_000,
                publicSalePrice: 0.069 ether,
                publicSaleDuration: 2 days,
                fundsRecipientSplit: 300_000,
                minter: FIXED_PRICE_MINTER
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                                DROPOSE
    //////////////////////////////////////////////////////////////*/

    /// Format proposal for a drop.
    /// For existing erc1155, AgoraNounsGovernor requires admin rights for the token being created.
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
                _createSplit(params.fundsRecipient, config.fundsRecipientSplit),
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
                params.animationURI,
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

        bytes memory minterData = abi.encodeCall(
            IZoraMinter(FIXED_PRICE_MINTER).setSale,
            (
                1,
                FixedPriceMinter_SalesConfig({
                    saleStart: publicSaleStart,
                    saleEnd: publicSaleStart + config.publicSaleDuration,
                    maxTokensPerAddress: 0,
                    pricePerToken: config.publicSalePrice,
                    fundsRecipient: _createSplit(params.tokenParams.fundsRecipient, config.fundsRecipientSplit)
                })
            )
        );

        bytes[] memory setupActions = new bytes[](4);
        // setupNewToken
        setupActions[0] =
            abi.encodeCall(IZoraCreator1155.setupNewToken, (params.tokenParams.tokenURI, config.editionSize));
        // addPermission
        setupActions[1] = abi.encodeCall(IZoraCreator1155.addPermission, (1, FIXED_PRICE_MINTER, 2 ** 2));
        // callSale
        setupActions[2] = abi.encodeCall(IZoraCreator1155.callSale, (1, config.minter, minterData));
        // updateRoyaltiesForToken
        setupActions[3] = abi.encodeCall(
            IZoraCreator1155.updateRoyaltiesForToken, (1, _royaltyConfiguration(params.tokenParams.royaltyBPS))
        );

        // createContract
        targets[0] = address(zoraCreator1155Factory);
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

        uint256 tokenId = IZoraCreator1155(droposalParams.nftCollection).nextTokenId();

        bytes memory minterData = abi.encodeCall(
            IZoraMinter(FIXED_PRICE_MINTER).setSale,
            (
                tokenId,
                FixedPriceMinter_SalesConfig({
                    saleStart: publicSaleStart,
                    saleEnd: publicSaleStart + config.publicSaleDuration,
                    maxTokensPerAddress: 0,
                    pricePerToken: config.publicSalePrice,
                    fundsRecipient: _createSplit(params.fundsRecipient, config.fundsRecipientSplit)
                })
            )
        );

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
    }

    // TODO: Check royaltyBPS are correct
    function _royaltyConfiguration(uint256 royaltyBPS) internal view returns (RoyaltyConfiguration memory) {
        return
            RoyaltyConfiguration({royaltyMintSchedule: 0, royaltyBPS: uint32(royaltyBPS), royaltyRecipient: msg.sender});
    }

    // Remove split creation as it's there are no sepolia contracts
    function _createSplit(address, uint32) internal pure returns (address payable) {
        return payable(address(9));
        // return _createSplitMain(recipient, split);
    }

    /*//////////////////////////////////////////////////////////////
                             DROPOSAL TYPES
    //////////////////////////////////////////////////////////////*/

    /// Propose a new droposal type to be approved by contract owner.
    function proposeDroposalType(DroposalConfig memory config) public {
        unchecked {
            uint256 pendingDroposalTypeId = ++pendingDroposalTypesCount;

            pendingDroposalTypes[pendingDroposalTypeId] = config;
            emit DroposalTypeProposed(pendingDroposalTypeId, config);
        }
    }

    /// Approve a pending droposal type.
    /// @dev Only owner
    function approveDroposalType(uint256 droposalTypeId, uint256 pendingDroposalTypeId) public onlyOwner {
        if (
            droposalTypes[droposalTypeId].editionSize != 0
                || pendingDroposalTypes[pendingDroposalTypeId].editionSize == 0
        ) revert InvalidDroposalType();
        _setDroposalType(droposalTypeId, pendingDroposalTypes[pendingDroposalTypeId]);
        emit DroposalTypeApproved(pendingDroposalTypeId);
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

    function _createSplitSlice(address recipient, uint32 split) internal returns (address payable) {
        Payee[] memory payees = new Payee[](2);
        payees[0] = Payee({account: recipient, shares: split, transfersAllowedWhileLocked: false});
        payees[1] = Payee({account: nounsReceiver, shares: 10000 - split, transfersAllowedWhileLocked: false});

        // TODO: What currencies should it accept?
        // address[] memory currencies = new address[](0);
        // currencies[0] = address(usdc);

        slice.slice(
            SliceParams({
                payees: payees,
                minimumShares: 5001,
                currencies: new address[](0),
                releaseTimelock: 0,
                transferTimelock: 0, // TODO: should transfers be locked?
                controller: recipient,
                slicerFlags: 1 << 1, // Enable currencies control
                sliceCoreFlags: 0
            })
        );

        // TODO: Test slicer id is correct in encode1155

        return payable(slice.slicers(slice.supply()));
    }

    function _createSplitMain(address recipient, uint32 split) internal returns (address payable) {
        address[] memory accounts = new address[](2);
        accounts[0] = recipient;
        accounts[1] = address(nounsGovernor);

        uint32[] memory percentAllocations = new uint32[](2);
        percentAllocations[0] = split;
        percentAllocations[1] = SPLIT_PERCENTAGE_SCALE - split;

        return splitMain.createSplit(
            accounts,
            percentAllocations,
            0, // distributorFee
            address(0) // controller
        );
    }

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
