// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @notice The RoyaltyConfiguration struct is used to store the royalty configuration for a given token.
/// @param royaltyMintSchedule Every nth token will go to the royalty recipient.
/// @param royaltyBPS The royalty amount in basis points for secondary sales.
/// @param royaltyRecipient The address that will receive the royalty payments.
struct RoyaltyConfiguration {
    uint32 royaltyMintSchedule;
    uint32 royaltyBPS;
    address royaltyRecipient;
}

interface IZoraCreator1155 {
    event SetupNewToken(uint256 indexed tokenId, address indexed sender, string newURI, uint256 maxSupply);

    event ContractMetadataUpdated(address indexed updater, string uri, string name);
    event Purchased(
        address indexed sender, address indexed minter, uint256 indexed tokenId, uint256 quantity, uint256 value
    );
    event CreatorAttribution(bytes32 structHash, string domainName, string version, address creator, bytes signature);

    /// @notice Only allow minting one token id at time
    /// @dev Mint contract function that calls the underlying sales function for commands
    /// @param minter Address for the minter
    /// @param tokenId tokenId to mint, set to 0 for new tokenId
    /// @param quantity to mint
    /// @param minterArguments calldata for the minter contracts
    function mint(address minter, uint256 tokenId, uint256 quantity, bytes calldata minterArguments) external payable;

    function adminMint(address recipient, uint256 tokenId, uint256 quantity, bytes memory data) external;

    function adminMintBatch(
        address recipient,
        uint256[] memory tokenIds,
        uint256[] memory quantities,
        bytes memory data
    ) external;

    function burnBatch(address user, uint256[] calldata tokenIds, uint256[] calldata amounts) external;

    /// @notice Contract call to setupNewToken
    /// @param tokenURI URI for the token
    /// @param maxSupply maxSupply for the token, set to 0 for open edition
    function setupNewToken(string memory tokenURI, uint256 maxSupply) external returns (uint256 tokenId);

    function updateTokenURI(uint256 tokenId, string memory _newURI) external;

    function updateContractMetadata(string memory _newURI, string memory _newName) external;

    // Public interface for `setTokenMetadataRenderer(uint256, address) has been deprecated.

    function contractURI() external view returns (string memory);

    function assumeLastTokenIdMatches(uint256 tokenId) external;

    function updateRoyaltiesForToken(uint256 tokenId, RoyaltyConfiguration memory royaltyConfiguration) external;

    function addPermission(uint256 tokenId, address user, uint256 permissionBits) external;

    function removePermission(uint256 tokenId, address user, uint256 permissionBits) external;

    function callRenderer(uint256 tokenId, bytes memory data) external;

    function callSale(uint256 tokenId, address salesConfig, bytes memory data) external;

    function mintFee() external view returns (uint256);

    function isAdminOrRole(address user, uint256 tokenId, uint256 role) external view returns (bool);

    function nextTokenId() external view returns (uint256);

    function owner() external view returns (address);

    function setOwner(address newOwner) external;
}
