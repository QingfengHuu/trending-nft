// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TrendingMetadataRegistry
 * @notice Stores on-chain minimal registry for trending metadata used to provide on-chain proof of:
 * - trending title (short)
 * - promptHash (keccak256 of the final prompt; full prompt stored off-chain)
 * - totalVotes
 * - metadataCID (IPFS CID for the full JSON which contains image URL and long newsDetail)
 *
 * Design rationale:
 * - To minimize gas, store only short strings and hashes on-chain. Full prompt and long newsDetail
 * should be uploaded to IPFS and referenced by metadataCID.
 * - Only owner (backend) can register or update metadata.
 */

import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract TrendingMetadataRegistry is Ownable {
    struct TrendingMetadata {
        string title; // short title (e.g., "Event X - 2025-09-22")
        bytes32 promptHash; // keccak256 hash of the final prompt (integrity proof)
        uint256 totalVotes; // vote count when finalizing
        string metadataCID; // ipfs CID pointing to the full JSON (contains prompt, newsDetail, image links)
        uint256 createdAt;
        uint256 updatedAt;
        bool exists;
    }

    // tokenId => metadata
    mapping(uint256 => TrendingMetadata) private _metadatas;

    constructor() Ownable(msg.sender) {}

    event MetadataRegistered(
        uint256 indexed tokenId,
        address indexed registrar,
        string metadataCID
    );
    event MetadataUpdated(
        uint256 indexed tokenId,
        address indexed updater,
        string metadataCID
    );

    /**
     * @notice Register metadata for a given tokenId. Only owner (backend) may call.
     * @dev If metadata already exists, this will overwrite fields and update timestamps.
     * @param tokenId The tokenId created in the TrendingNFT contract
     * @param title Short title for the trending event
     * @param promptHash keccak256 hash of the final prompt (bytes32)
     * @param totalVotes Final vote count
     * @param metadataCID IPFS CID pointing to a JSON containing full prompt, newsDetail and image CID
     */
    function registerMetadata(
        uint256 tokenId,
        string calldata title,
        bytes32 promptHash,
        uint256 totalVotes,
        string calldata metadataCID
    ) external onlyOwner {
        TrendingMetadata storage m = _metadatas[tokenId];

        m.title = title;
        m.promptHash = promptHash;
        m.totalVotes = totalVotes;
        m.metadataCID = metadataCID;

        if (!m.exists) {
            m.createdAt = block.timestamp;
            m.exists = true;
            emit MetadataRegistered(tokenId, msg.sender, metadataCID);
        } else {
            emit MetadataUpdated(tokenId, msg.sender, metadataCID);
        }

        m.updatedAt = block.timestamp;
    }

    /**
     * @notice Read metadata fields for tokenId.
     * @return title Short title
     * @return promptHash keccak256 hash of the prompt
     * @return totalVotes final vote count
     * @return metadataCID IPFS CID
     * @return createdAt timestamp when first registered
     * @return updatedAt timestamp when last updated
     * @return exists whether metadata exists
     */
    function getMetadata(
        uint256 tokenId
    )
        external
        view
        returns (
            string memory title,
            bytes32 promptHash,
            uint256 totalVotes,
            string memory metadataCID,
            uint256 createdAt,
            uint256 updatedAt,
            bool exists
        )
    {
        TrendingMetadata storage m = _metadatas[tokenId];
        return (
            m.title,
            m.promptHash,
            m.totalVotes,
            m.metadataCID,
            m.createdAt,
            m.updatedAt,
            m.exists
        );
    }

    /**
     * @notice Convenience getter for metadataCID only.
     */
    function getMetadataCID(
        uint256 tokenId
    ) external view returns (string memory) {
        return _metadatas[tokenId].metadataCID;
    }

    /**
     * @notice Check if metadata exists for tokenId.
     */
    function existsMetadata(uint256 tokenId) external view returns (bool) {
        return _metadatas[tokenId].exists;
    }

    /**
     * @notice Owner can delete metadata if needed (use carefully).
     */
    function deleteMetadata(uint256 tokenId) external onlyOwner {
        require(
            _metadatas[tokenId].exists,
            "TrendingMetadataRegistry: not exists"
        );
        delete _metadatas[tokenId];
    }
}
