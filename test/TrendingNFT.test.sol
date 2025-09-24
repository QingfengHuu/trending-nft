// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TrendingNFT.sol";

contract TrendingNFTTest is Test {
    TrendingNFT public trendingNFT;
    uint256 public constant MINT_PRICE = 0.001 ether;
    uint256 public constant DAILY_DURATION = 1 days;

    address public owner = address(1);
    address public user = address(2);
    address public user2 = address(3);

    function setUp() public {
        vm.startPrank(owner);
        trendingNFT = new TrendingNFT("https://default.com");
        trendingNFT.createTrending("https://test.com/token/1");
        vm.stopPrank();
    }

    function testMintWithCorrectEth() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        // Mint 3 tokens with correct ETH amount
        uint256 amount = 3;
        trendingNFT.mint{value: MINT_PRICE * amount}(amount);

        assertEq(trendingNFT.totalMinted(1), amount);
        vm.stopPrank();
    }

    function testMintWithIncorrectEth() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        // Try to mint with incorrect ETH amount
        vm.expectRevert("TrendingNFT: Exact ETH amount required");
        trendingNFT.mint{value: 0.0001 ether}(1);

        vm.stopPrank();
    }

    function testCurrentDailyId() public {
        vm.startPrank(owner);
        assertEq(trendingNFT.currentDailyId(), 1);
        vm.stopPrank();
    }

    function testCreateTrending() public {
        // Move time forward by 1 day to allow creating new trending
        vm.warp(block.timestamp + DAILY_DURATION);

        vm.startPrank(owner);
        string memory newURI = "https://test.com/token/2";

        uint256 newId = trendingNFT.createTrending(newURI);

        assertEq(newId, 2);
        assertEq(trendingNFT.currentDailyId(), newId);
        vm.stopPrank();
    }

    function testUri() public {
        vm.startPrank(owner);
        string memory tokenURI = "https://test.com/token/1";
        assertEq(trendingNFT.uri(1), tokenURI);
        vm.stopPrank();
    }

    function testUriNonExistentToken() public {
        vm.startPrank(owner);
        vm.expectRevert("TrendingNFT: URI not set for tokenId");
        trendingNFT.uri(999);
        vm.stopPrank();
    }

    function testSetTokenURI() public {
        vm.startPrank(owner);
        string memory newURI = "https://updated.com/token/1";

        trendingNFT.setTokenURI(1, newURI);

        assertEq(trendingNFT.uri(1), newURI);
        vm.stopPrank();
    }

    function testSetTokenURINonExistentToken() public {
        vm.startPrank(owner);
        vm.expectRevert("TrendingNFT: Token does not exist");
        trendingNFT.setTokenURI(999, "https://test.com/token/999");
        vm.stopPrank();
    }

    function testSetTokenURINotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );
        trendingNFT.setTokenURI(1, "https://test.com/token/2");
        vm.stopPrank();
    }

    function testCreateTrendingNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );
        trendingNFT.createTrending("https://test.com/token/2");
        vm.stopPrank();
    }

    function testWithdrawNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );
        trendingNFT.withdraw();
        vm.stopPrank();
    }

    function testWithdrawZeroBalance() public {
        vm.startPrank(owner);
        vm.expectRevert("TrendingNFT: No ETH to withdraw");
        trendingNFT.withdraw();
        vm.stopPrank();
    }

    function testMintZeroValue() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        // Try to mint with 0 amount should fail
        vm.expectRevert("TrendingNFT: Amount must be greater than zero");
        trendingNFT.mint{value: 0}(0);

        assertEq(trendingNFT.totalMinted(1), 0);
        vm.stopPrank();
    }

    function testMintEvents() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        vm.expectEmit(true, true, false, true);
        emit TrendingNFT.TrendingMinted(user, 1, 1);

        trendingNFT.mint{value: MINT_PRICE}(1);
        vm.stopPrank();
    }

    function testCreateTrendingEvents() public {
        // Move time forward by 1 day to allow creating new trending
        vm.warp(block.timestamp + DAILY_DURATION);

        vm.startPrank(owner);

        uint256 todayStart = (block.timestamp / DAILY_DURATION) *
            DAILY_DURATION;
        vm.expectEmit(true, false, false, true);
        emit TrendingNFT.TrendingCreated(
            2,
            "https://test.com/token/2",
            todayStart
        );

        trendingNFT.createTrending("https://test.com/token/2");
        vm.stopPrank();
    }

    function testMintAfterExpiration() public {
        // Move time forward past the daily duration
        vm.warp(block.timestamp + DAILY_DURATION);

        vm.deal(user, 1 ether);
        vm.startPrank(user);

        vm.expectRevert("TrendingNFT: Daily mint expired");
        trendingNFT.mint{value: MINT_PRICE}(1);

        vm.stopPrank();
    }

    function testCreateTrendingSameDay() public {
        vm.startPrank(owner);

        vm.expectRevert("TrendingNFT: Today's NFT already created");
        trendingNFT.createTrending("https://test.com/token/2");

        vm.stopPrank();
    }

    function testGetCurrentTrending() public {
        vm.startPrank(owner);

        (
            uint256 tokenId,
            string memory tokenURI,
            uint256 startTime,
            uint256 endTime,
            uint256 minted
        ) = trendingNFT.getCurrentTrending();

        assertEq(tokenId, 1);
        assertEq(tokenURI, "https://test.com/token/1");
        assertEq(
            startTime,
            (block.timestamp / DAILY_DURATION) * DAILY_DURATION
        );
        assertEq(endTime, startTime + DAILY_DURATION);
        assertEq(minted, 0);

        vm.stopPrank();
    }

    function testIsMintActive() public {
        vm.startPrank(owner);
        assertTrue(trendingNFT.isMintActive());
        vm.stopPrank();
    }

    function testIsMintNotActiveAfterExpiration() public {
        // Move time forward past the daily duration
        vm.warp(block.timestamp + DAILY_DURATION);

        vm.startPrank(owner);
        assertFalse(trendingNFT.isMintActive());
        vm.stopPrank();
    }

    function testWithdrawSuccess() public {
        // Mint some tokens to add ETH to contract
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        trendingNFT.mint{value: MINT_PRICE * 3}(3);
        vm.stopPrank();

        uint256 contractBalance = address(trendingNFT).balance;
        assertGt(contractBalance, 0);

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit TrendingNFT.Withdrawal(owner, contractBalance);
        trendingNFT.withdraw();
        vm.stopPrank();
    }

    function testMintTransfersTokensToSender() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        uint256 amount = 2;
        trendingNFT.mint{value: MINT_PRICE * amount}(amount);

        assertEq(trendingNFT.balanceOf(user, 1), amount);
        vm.stopPrank();
    }
}
