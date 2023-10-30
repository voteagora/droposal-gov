// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {
    AgoraNounsGovernor,
    IZoraCreator721,
    IZoraCreator1155,
    IZoraCreator1155Factory,
    IZoraMinter,
    IERC721Drop,
    FixedPriceMinter_SalesConfig
} from "src/AgoraNounsGovernor.sol";
import {
    DroposalParams, NFTType, ERC721Params, ERC1155Params, ERC1155TokenParams
} from "src/structs/DroposalParams.sol";
import {DroposalConfig} from "src/structs/DroposalConfig.sol";

contract AgoraNounsGovernorMock is AgoraNounsGovernor {
    address payable public constant fundsRecipient = payable(0xd02cB8665a492F423Dc85630DF53321CD162b784);

    function getDroposalType(uint256 droposalTypeId) public view returns (DroposalConfig memory) {
        return droposalTypes[droposalTypeId];
    }

    function getPendingDroposalType(uint256 droposalTypeId) public view returns (DroposalConfig memory) {
        return pendingDroposalTypes[droposalTypeId];
    }

    function getPendingDroposalTypesCount() public view returns (uint256) {
        return pendingDroposalTypesCount;
    }

    function encode721Data(uint64 publicSaleStart, DroposalParams memory droposalParams, DroposalConfig memory config)
        public
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
                fundsRecipient,
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

    function encode1155Data(uint64 publicSaleStart, DroposalParams memory droposalParams, DroposalConfig memory config)
        public
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
                    fundsRecipient: fundsRecipient
                })
            )
        );

        bytes[] memory setupActions = new bytes[](4);
        // setupNewToken
        setupActions[0] =
            abi.encodeCall(IZoraCreator1155.setupNewToken, (params.tokenParams.tokenURI, config.editionSize));
        // addPermission
        setupActions[1] = abi.encodeCall(IZoraCreator1155.addPermission, (1, FIXED_PRICE_MINTER, 2 ** 2));
        // // callSale
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

    function encodeExisting1155Data(
        uint64 publicSaleStart,
        DroposalParams memory droposalParams,
        DroposalConfig memory config
    ) public view returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
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
                    fundsRecipient: fundsRecipient
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

    function createSlice(address recipient, uint32 split) public returns (address) {
        return _createSplitSlice(recipient, split);
    }

    function forceExecute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }
}
