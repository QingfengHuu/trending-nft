// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TrendingNFT (ERC1155)
 * @notice ERC-1155 contract to manage "trending" NFT series.
 * - Owner (backend) can create a new trending id with a tokenURI.
 * - Anyone can mint editions of a trending id by paying 0.001 ETH per token,
 * or the owner can mint on behalf of addresses for free.
 * - The contract stores only tokenURI mapping and supply tracking.
 */

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract TrendingNFT is ERC1155, Ownable {
    uint256 private _idCounter;

    // Fixed mint price: 0.001 ETH
    uint256 public constant MINT_PRICE = 0.001 ether;

    // tokenId => tokenURI
    mapping(uint256 => string) private _tokenURIs;

    // tokenId => minted amount
    mapping(uint256 => uint256) public totalMinted;

    // Daily trending id
    uint256 public currentDailyId;

    // Daily trending start
    uint256 public dailyStart;

    // Daily duration
    uint256 public constant DAILY_DURATION = 1 days;

    // Events
    event TrendingCreated(
        uint256 indexed tokenId,
        string tokenURI,
        uint256 startTime
    );
    event TrendingMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 amount
    );
    event Withdrawal(address indexed to, uint256 amount);

    /**
     * @dev Constructor sets a default URI (can be empty). We override uri(tokenId) to return per-token URI.
     */
    constructor(
        string memory defaultURI
    ) ERC1155(defaultURI) Ownable(msg.sender) {}

    /**
     * @notice Create a new trending NFT id.
     * @dev Only owner (backend) can create new trending ids.
     * @param tokenURI The metadata URI (typically ipfs://... or https://...) for this tokenId.
     * @return tokenId The newly created token id.
     */
    function createTrending(
        string calldata tokenURI
    ) external onlyOwner returns (uint256) {
        require(
            currentDailyId == 0 ||
                block.timestamp > dailyStart + DAILY_DURATION,
            "TrendingNFT: Todays's NFT already created"
        );

        _idCounter++;
        uint256 newId = _idCounter;

        _tokenURIs[newId] = tokenURI;
        totalMinted[newId] = 0;

        currentDailyId = newId;
        dailyStart = block.timestamp;

        emit TrendingCreated(newId, tokenURI, dailyStart);
        return newId;
    }

    /**
     * @notice Owner can mint `amount` editions of tokenId to `to` for free (useful for initial distribution).
     */
    function ownerMint(address to, uint256 amount) external onlyOwner {
        require(currentDailyId != 0, "TrendingNFT: No daily NFT available");
        require(
            block.timestamp < dailyStart + DAILY_DURATION,
            "TrendingNFT: Daily mint expired"
        );

        totalMinted[currentDailyId] += amount;
        _mint(to, currentDailyId, amount, "");

        emit TrendingMinted(to, currentDailyId, amount);
    }

    /**
     * @notice Public mint function: users can mint editions by paying 0.001 ETH per token.
     * @param amount number of editions to mint
     */
    function mint(uint256 amount) external payable {
        require(currentDailyId != 0, "TrendingNFT: No daily NFT available");
        require(
            block.timestamp < dailyStart + DAILY_DURATION,
            "TrendingNFT: Daily mint expired"
        );

        // Check that the correct amount of ETH was sent
        require(
            msg.value == MINT_PRICE * amount,
            "TrendingNFT: Incorrect ETH amount sent"
        );

        totalMinted[currentDailyId] += amount;
        _mint(msg.sender, currentDailyId, amount, "");

        emit TrendingMinted(msg.sender, currentDailyId, amount);
    }

    /**
     * @notice Returns the metadata URI for `tokenId`.
     * @dev Overrides ERC1155.uri to return the stored tokenURI.
     */
    function uri(uint256 tokenId) public view override returns (string memory) {
        string memory tokenUri = _tokenURIs[tokenId];
        require(
            bytes(tokenUri).length != 0,
            "TrendingNFT: URI not set for tokenId"
        );
        return tokenUri;
    }

    /**
     * @notice Owner can update the tokenURI for a given tokenId (in case metadata moved or updated).
     * @dev Use carefully — changing metadata URI is a state change and should be controlled.
     */
    function setTokenURI(
        uint256 tokenId,
        string calldata newURI
    ) external onlyOwner {
        require(bytes(_tokenURIs[tokenId]).length != 0, "Token does not exist");

        _tokenURIs[tokenId] = newURI;
    }

    /**
     * @notice Withdraw contract balance to owner
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "TrendingNFT: No ETH to withdraw");

        address payable ownerPayable = payable(owner());
        (bool success, ) = ownerPayable.call{value: balance}("");
        require(success, "TrendingNFT: ETH transfer failed");
        emit Withdrawal(owner(), balance);
    }
}
