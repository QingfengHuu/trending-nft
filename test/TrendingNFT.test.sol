// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TrendingNFT.sol";

contract TrendingNFTTest is Test {
    TrendingNFT public trendingNFT;
    uint256 public constant MINT_PRICE = 0.001 ether;

    address public owner = address(1);
    address public user = address(2);
    address public user2 = address(3);

    uint256 public testTokenId;

    function setUp() public {
        vm.startPrank(owner);
        trendingNFT = new TrendingNFT("https://default.com");
        testTokenId = trendingNFT.createTrending("https://test.com/token/1");
        vm.stopPrank();
    }

    function testMintWithCorrectEth() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        // Mint 3 tokens with correct ETH amount
        uint256 amount = 3;
        trendingNFT.mint{value: MINT_PRICE * amount}(testTokenId, amount);

        assertEq(trendingNFT.totalMinted(testTokenId), amount);
        vm.stopPrank();
    }

    function testMintWithIncorrectEth() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        // Try to mint with incorrect ETH amount
        vm.expectRevert("TrendingNFT: Incorrect ETH amount sent");
        trendingNFT.mint{value: 0.0001 ether}(testTokenId, 1);

        vm.stopPrank();
    }

    function testOwnerMintWithoutEth() public {
        vm.startPrank(owner);

        // Owner can mint without sending ETH
        uint256 amount = 5;
        trendingNFT.ownerMint(user, testTokenId, amount);

        assertEq(trendingNFT.totalMinted(testTokenId), amount);
        vm.stopPrank();
    }

    function testCurrentTokenId() public {
        vm.startPrank(owner);
        uint256 newTokenId = trendingNFT.createTrending(
            "https://test.com/token/2"
        );
        assertEq(trendingNFT.currentTokenId(), newTokenId);
        vm.stopPrank();
    }

    function testCreateTrending() public {
        vm.startPrank(owner);
        uint256 initialTokenId = trendingNFT.currentTokenId();
        string memory newURI = "https://test.com/token/3";

        uint256 newTokenId = trendingNFT.createTrending(newURI);

        assertEq(newTokenId, initialTokenId + 1);
        assertEq(trendingNFT.currentTokenId(), newTokenId);
        vm.stopPrank();
    }

    function testUri() public {
        vm.startPrank(owner);
        string memory tokenURI = "https://test.com/token/1";
        assertEq(trendingNFT.uri(testTokenId), tokenURI);
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

        trendingNFT.setTokenURI(testTokenId, newURI);

        assertEq(trendingNFT.uri(testTokenId), newURI);
        vm.stopPrank();
    }

    function testSetTokenURINonExistentToken() public {
        vm.startPrank(owner);
        vm.expectRevert("TrendingNFT: tokenId does not exist");
        trendingNFT.setTokenURI(999, "https://test.com/token/999");
        vm.stopPrank();
    }

    function testSetTokenURINotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );
        trendingNFT.setTokenURI(testTokenId, "https://test.com/token/2");
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

    function testOwnerMintNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );
        trendingNFT.ownerMint(user, testTokenId, 1);
        vm.stopPrank();
    }

    function testMintNonExistentToken() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);
        vm.expectRevert("TrendingNFT: tokenId does not exist");
        trendingNFT.mint{value: MINT_PRICE}(999, 1);
        vm.stopPrank();
    }

    function testOwnerMintNonExistentToken() public {
        vm.startPrank(owner);
        vm.expectRevert("TrendingNFT: tokenId does not exist");
        trendingNFT.ownerMint(user, 999, 1);
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

        // Mint with 0 amount should work (but not mint anything)
        trendingNFT.mint{value: 0}(testTokenId, 0);

        assertEq(trendingNFT.totalMinted(testTokenId), 0);
        vm.stopPrank();
    }

    function testMintEvents() public {
        vm.deal(user, 1 ether);
        vm.startPrank(user);

        vm.expectEmit(true, true, false, true);
        emit TrendingNFT.TrendingMinted(user, testTokenId, 1);

        trendingNFT.mint{value: MINT_PRICE}(testTokenId, 1);
        vm.stopPrank();
    }

    function testOwnerMintEvents() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, false, true);
        emit TrendingNFT.TrendingMinted(user, testTokenId, 1);

        trendingNFT.ownerMint(user, testTokenId, 1);
        vm.stopPrank();
    }

    function testCreateTrendingEvents() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);
        emit TrendingNFT.TrendingCreated(2, "https://test.com/token/2");

        trendingNFT.createTrending("https://test.com/token/2");
        vm.stopPrank();
    }
}
