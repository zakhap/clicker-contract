// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/CharityRouter.sol";

contract DeployCharityRouter is Script {
    CharityRouter public router;

    // Hardcoded final owner address (replace with desired address)
    address constant FINAL_OWNER = 0x742D35cc6464c021b9A3b6D3e3ED1Ac1a0ed0c9B;

    // Charity data for batch addition - using valid checksummed Ethereum addresses
    string[] charityNames = ["American Red Cross", "Doctors Without Borders", "Save the Children"];

    address payable[] charityAddresses = [
        payable(0xdAC17F958D2ee523a2206206994597C13D831ec7), // USDT contract address (valid)
        payable(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599), // WBTC contract address (valid)
        payable(0xa0B86a33e6441E64b03C15a1C57E7c6c5b9DC9F0) // Valid checksummed address
    ];

    function run() external {
        // Get deployer address from msg.sender (set by forge script)
        address deployer = msg.sender;

        console.log("=== CharityRouter Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Final owner will be:", FINAL_OWNER);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast();

        // Step 1: Deploy contract with deployer as initial owner
        console.log("1. Deploying CharityRouter contract...");
        router = new CharityRouter(deployer);
        console.log("   Contract deployed at:", address(router));
        console.log("   Initial owner:", router.owner());
        console.log("   Version:", router.getVersion());
        console.log("");

        // Step 2: Batch add charities
        console.log("2. Adding charities in batch...");
        console.log("   Adding", charityNames.length, "charities:");
        for (uint256 i = 0; i < charityNames.length; i++) {
            console.log("   -", charityNames[i], "at", charityAddresses[i]);
        }

        router.addCharitiesBatch(charityNames, charityAddresses);
        console.log("   SUCCESS: Charities added successfully");
        console.log("   Total charities:", router.getCharityCount());
        console.log("");

        // Step 3: Transfer ownership to final owner
        console.log("3. Transferring ownership...");
        console.log("   From:", router.owner());
        console.log("   To:", FINAL_OWNER);

        router.transferOwnership(FINAL_OWNER);
        console.log("   SUCCESS: Ownership transfer initiated");
        console.log("   Pending owner:", router.pendingOwner());
        console.log("");

        vm.stopBroadcast();

        // Step 4: Verify deployment
        console.log("=== Deployment Summary ===");
        console.log("Contract Address:", address(router));
        console.log("Current Owner:", router.owner());
        console.log("Pending Owner:", router.pendingOwner());
        console.log("Total Charities:", router.getCharityCount());

        // Display charity details
        console.log("\nRegistered Charities:");
        address[] memory allCharities = router.getAllCharities();
        for (uint256 i = 0; i < allCharities.length; i++) {
            (string memory name, bool isActive, uint256 totalEthReceived, uint256 donationCount, uint256 registeredAt) =
                router.getCharityStats(allCharities[i]);

            console.log("  ", i + 1, ".", name);
            console.log("     Address:", allCharities[i]);
            console.log("     Active:", isActive);
            console.log("     ETH Received:", totalEthReceived);
            console.log("     Donations:", donationCount);
            console.log("     Registered:", registeredAt);
            console.log("");
        }

        console.log("DEPLOYMENT COMPLETED SUCCESSFULLY!");
        console.log("");
        console.log("IMPORTANT: The new owner must call acceptOwnership() to complete the transfer:");
        console.log("   router.acceptOwnership() from address:", FINAL_OWNER);
        console.log("");
        console.log("Contract is ready to receive donations!");
    }
}
