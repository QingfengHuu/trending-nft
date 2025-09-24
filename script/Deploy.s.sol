// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {TrendingNFT} from "../src/TrendingNFT.sol";
import {TrendingMetadataRegistry} from "../src/TrendingMetadataRegistry.sol";

contract Deploy is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying contracts with account:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        TrendingNFT nft = new TrendingNFT("");
        TrendingMetadataRegistry registry = new TrendingMetadataRegistry();

        console.log("TrendingNFT deployed at:", address(nft));
        console.log("TrendingMetadataRegistry deployed at:", address(registry));

        vm.stopBroadcast();
    }
}
