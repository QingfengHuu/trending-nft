// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TrendingMetadataRegistry.sol";

contract TrendingMetadataRegistryTest is Test {
    TrendingMetadataRegistry public registry;

    address public owner = address(1);
    address public user = address(2);

    uint256 public testTokenId = 1;
    string public testTitle = "Event X - 2025-09-22";
    bytes32 public testPromptHash = keccak256("test prompt");
    uint256 public testTotalVotes = 100;
    string public testMetadataCID = "Qmabcdefghijklmnopqrstuvwxyz1234567890";

    function setUp() public {
        vm.startPrank(owner);
        registry = new TrendingMetadataRegistry();
        vm.stopPrank();
    }

    // Test constructor and ownership
    function testConstructor() public view {
        assertEq(registry.owner(), owner);
    }

    // Test registerMetadata function
    function testRegisterMetadata() public {
        vm.startPrank(owner);

        vm.expectEmit(true, true, false, true);
        emit TrendingMetadataRegistry.MetadataRegistered(
            testTokenId,
            owner,
            testMetadataCID
        );

        registry.registerMetadata(
            testTokenId,
            testTitle,
            testPromptHash,
            testTotalVotes,
            testMetadataCID
        );

        vm.stopPrank();

        // Check that metadata was registered correctly
        (
            string memory title,
            bytes32 promptHash,
            uint256 totalVotes,
            string memory metadataCID,
            uint256 createdAt,
            uint256 updatedAt,
            bool exists
        ) = registry.getMetadata(testTokenId);

        assertEq(title, testTitle);
        assertEq(promptHash, testPromptHash);
        assertEq(totalVotes, testTotalVotes);
        assertEq(metadataCID, testMetadataCID);
        assertTrue(createdAt > 0);
        assertTrue(updatedAt > 0);
        assertTrue(exists);
        assertEq(createdAt, updatedAt);
    }

    // Test registerMetadata when not owner
    function testRegisterMetadataNotOwner() public {
        vm.startPrank(user);

        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );

        registry.registerMetadata(
            testTokenId,
            testTitle,
            testPromptHash,
            testTotalVotes,
            testMetadataCID
        );

        vm.stopPrank();
    }

    // Test updating existing metadata
    function testUpdateMetadata() public {
        // First register metadata
        vm.startPrank(owner);
        registry.registerMetadata(
            testTokenId,
            testTitle,
            testPromptHash,
            testTotalVotes,
            testMetadataCID
        );

        // Get the creation timestamp
        (, , , , uint256 createdAt, , ) = registry.getMetadata(testTokenId);

        // Advance time
        vm.warp(block.timestamp + 1 days);

        string memory newTitle = "Event Y - 2025-09-23";
        bytes32 newPromptHash = keccak256("new prompt");
        uint256 newTotalVotes = 150;
        string
            memory newMetadataCID = "Qmnewabcdefghijklmnopqrstuvwxyz1234567890";

        vm.expectEmit(true, true, false, true);
        emit TrendingMetadataRegistry.MetadataUpdated(
            testTokenId,
            owner,
            newMetadataCID
        );

        registry.registerMetadata(
            testTokenId,
            newTitle,
            newPromptHash,
            newTotalVotes,
            newMetadataCID
        );

        vm.stopPrank();

        // Check that metadata was updated correctly
        (
            string memory title,
            bytes32 promptHash,
            uint256 totalVotes,
            string memory metadataCID,
            uint256 createdAtAfter,
            uint256 updatedAt,
            bool exists
        ) = registry.getMetadata(testTokenId);

        assertEq(title, newTitle);
        assertEq(promptHash, newPromptHash);
        assertEq(totalVotes, newTotalVotes);
        assertEq(metadataCID, newMetadataCID);
        assertEq(createdAtAfter, createdAt);
        assertTrue(updatedAt > createdAt);
        assertTrue(exists);
    }

    // Test getMetadataCID function
    function testGetMetadataCID() public {
        vm.startPrank(owner);
        registry.registerMetadata(
            testTokenId,
            testTitle,
            testPromptHash,
            testTotalVotes,
            testMetadataCID
        );
        vm.stopPrank();

        string memory metadataCID = registry.getMetadataCID(testTokenId);
        assertEq(metadataCID, testMetadataCID);
    }

    // Test getMetadataCID for non-existent token
    function testGetMetadataCIDNonExistent() public view {
        string memory metadataCID = registry.getMetadataCID(999);
        assertEq(bytes(metadataCID).length, 0);
    }

    // Test existsMetadata function
    function testExistsMetadata() public {
        assertFalse(registry.existsMetadata(testTokenId));

        vm.startPrank(owner);
        registry.registerMetadata(
            testTokenId,
            testTitle,
            testPromptHash,
            testTotalVotes,
            testMetadataCID
        );
        vm.stopPrank();

        assertTrue(registry.existsMetadata(testTokenId));
    }

    // Test deleteMetadata function
    function testDeleteMetadata() public {
        // First register metadata
        vm.startPrank(owner);
        registry.registerMetadata(
            testTokenId,
            testTitle,
            testPromptHash,
            testTotalVotes,
            testMetadataCID
        );

        assertTrue(registry.existsMetadata(testTokenId));

        registry.deleteMetadata(testTokenId);

        assertFalse(registry.existsMetadata(testTokenId));

        vm.stopPrank();
    }

    // Test deleteMetadata when not owner
    function testDeleteMetadataNotOwner() public {
        // First register metadata as owner
        vm.startPrank(owner);
        registry.registerMetadata(
            testTokenId,
            testTitle,
            testPromptHash,
            testTotalVotes,
            testMetadataCID
        );
        vm.stopPrank();

        // Try to delete as non-owner
        vm.startPrank(user);
        vm.expectRevert(
            abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user)
        );
        registry.deleteMetadata(testTokenId);
        vm.stopPrank();
    }

    // Test deleteMetadata for non-existent token
    function testDeleteMetadataNonExistent() public {
        vm.startPrank(owner);
        vm.expectRevert("TrendingMetadataRegistry: not exists");
        registry.deleteMetadata(999);
        vm.stopPrank();
    }
}
