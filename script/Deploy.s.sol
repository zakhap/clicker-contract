// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/CharityRouter.sol";

contract DeployCharityRouter is Script {
    CharityRouter public router;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying CharityRouter...");
        console.log("Deployer address:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy with deployer as initial owner
        router = new CharityRouter(deployer);
        
        console.log("CharityRouter deployed to:", address(router));
        console.log("Owner:", router.owner());
        console.log("Version:", router.getVersion());
        
        vm.stopBroadcast();
    }
}