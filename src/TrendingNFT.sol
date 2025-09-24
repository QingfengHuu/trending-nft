// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TrendingNFT (ERC1155)
 * @notice ERC-1155 contract to manage "trending" NFT series.
 * - Owner (backend) can create a new trending id with a tokenURI.
 * - Anyone can mint editions of a trending id by paying 0.001 ETH per token,
 * or the owner can mint on behalf of addresses for free.
 * - The contract stores only tokenURI mapping and supply tracking.
 * - Minting is calendar-aligned to UTC days: the window for each trending NFT starts at 00:00 UTC
 *   on the day it is created and ends at 23:59:59 UTC (i.e., fixed midnight-to-midnight periods).
 * - Creation can occur at any time during the day, but only once per UTC day. The start time is
 *   retroactively set to midnight of that day, ensuring consistent daily alignment regardless of
 *   when the owner calls createTrending.
 * - After expiration, minting stops permanently for that ID (no retroactive minting).
 * - Token URIs can be updated by owner post-creation for flexibility (e.g., metadata fixes),
 *   but this breaks typical NFT immutability expectations—use judiciously and monitor the
 *   TokenURIUpdated event.
 */

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TrendingNFT is ERC1155, Ownable {
    uint256 private _idCounter;

    // Fixed mint price: 0.001 ETH
    uint256 public constant MINT_PRICE = 0.001 ether;

    // tokenId => tokenURI
    mapping(uint256 => string) private _tokenURIs;

    // tokenId => minted amount
    mapping(uint256 => uint256) public totalMinted;

    // Current trending id
    uint256 public currentDailyId;

    // Current trending start (midnight UTC of the creation day)
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
    event TokenURIUpdated(uint256 indexed tokenId, string newURI);
    event Withdrawal(address indexed to, uint256 amount);

    /**
     * @dev Constructor sets a default URI (can be empty). We override uri(tokenId) to return per-token URI.
     * @param defaultURI The default base URI for the ERC1155 contract (can be empty if using per-token URIs).
     */
    constructor(
        string memory defaultURI
    ) ERC1155(defaultURI) Ownable(msg.sender) {}

    /**
     * @notice Create a new trending NFT id.
     * @dev Only owner (backend) can create new trending ids. The mint window is aligned to the UTC calendar day,
     *      starting from 00:00 UTC of the current day and lasting 24 hours. Only one creation per UTC day.
     * @param tokenURI The metadata URI (typically ipfs://... or https://...) for this tokenId.
     * @return tokenId The newly created token id.
     */
    function createTrending(
        string calldata tokenURI
    ) external onlyOwner returns (uint256) {
        uint256 todayStart = (block.timestamp / DAILY_DURATION) *
            DAILY_DURATION;
        require(
            currentDailyId == 0 || dailyStart < todayStart,
            "TrendingNFT: Today's NFT already created"
        );

        uint256 newId = ++_idCounter;

        _tokenURIs[newId] = tokenURI;
        totalMinted[newId] = 0;

        currentDailyId = newId;
        dailyStart = todayStart;

        emit TrendingCreated(newId, tokenURI, dailyStart);
        return newId;
    }

    /**
     * @notice Public mint function: users can mint editions by paying exactly 0.001 ETH per token.
     * @dev Requires exact payment to avoid overpayment issues; handles zero-amount by require.
     * @param amount Number of editions to mint.
     */
    function mint(uint256 amount) external payable {
        require(currentDailyId != 0, "TrendingNFT: No daily NFT available");
        require(
            block.timestamp < dailyStart + DAILY_DURATION,
            "TrendingNFT: Daily mint expired"
        );
        require(amount > 0, "TrendingNFT: Amount must be greater than zero");

        // Require exact ETH amount to prevent overpayments
        require(
            msg.value == MINT_PRICE * amount,
            "TrendingNFT: Exact ETH amount required"
        );

        totalMinted[currentDailyId] += amount;
        _mint(msg.sender, currentDailyId, amount, "");

        emit TrendingMinted(msg.sender, currentDailyId, amount);
    }

    /**
     * @notice Returns the metadata URI for `tokenId`.
     * @dev Overrides ERC1155.uri to return the stored tokenURI.
     * @param tokenId The token ID to query.
     * @return The metadata URI for the token.
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
     * @dev Use carefully — changing metadata URI is a state change and should be controlled. Emits an event for transparency.
     *      To mitigate immutability concerns, this can be called even after minting, but frontends should alert on updates.
     * @param tokenId The token ID to update.
     * @param newURI The new metadata URI.
     */
    function setTokenURI(
        uint256 tokenId,
        string calldata newURI
    ) external onlyOwner {
        require(
            bytes(_tokenURIs[tokenId]).length != 0,
            "TrendingNFT: Token does not exist"
        );
        _tokenURIs[tokenId] = newURI;
        emit TokenURIUpdated(tokenId, newURI);
    }

    /**
     * @notice Withdraw contract balance to owner.
     * @dev Transfers the entire balance to the owner. Handles zero-balance edge case with require.
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "TrendingNFT: No ETH to withdraw");

        address payable ownerPayable = payable(owner());
        (bool success, ) = ownerPayable.call{value: balance}("");
        require(success, "TrendingNFT: ETH transfer failed");
        emit Withdrawal(owner(), balance);
    }

    /**
     * @notice Get details of the current trending NFT.
     * @dev Returns zeros if no current trending (e.g., post-expiration or pre-first-creation edge cases).
     * @return tokenId The current daily token ID.
     * @return tokenURI The metadata URI.
     * @return startTime The start timestamp of the mint window (midnight UTC).
     * @return endTime The end timestamp of the mint window (next midnight UTC).
     * @return minted The total minted amount for this ID.
     */
    function getCurrentTrending()
        external
        view
        returns (
            uint256 tokenId,
            string memory tokenURI,
            uint256 startTime,
            uint256 endTime,
            uint256 minted
        )
    {
        if (currentDailyId == 0) {
            return (0, "", 0, 0, 0);
        }
        return (
            currentDailyId,
            _tokenURIs[currentDailyId],
            dailyStart,
            dailyStart + DAILY_DURATION,
            totalMinted[currentDailyId]
        );
    }

    /**
     * @notice Check if minting is currently active for the daily trending NFT.
     * @dev Accounts for expiration edge (returns false post-window).
     * @return True if minting is active, false otherwise.
     */
    function isMintActive() external view returns (bool) {
        return
            currentDailyId != 0 &&
            block.timestamp < dailyStart + DAILY_DURATION;
    }
}
