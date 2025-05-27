// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/CharityRouter.sol";

contract CharityRouterViewFunctionsTest is Test {
    CharityRouter public router;
    address public owner;
    address public donor1;
    address public donor2;
    address payable public charity1;
    address payable public charity2;
    address payable public charity3;
    address payable public inactiveCharity;
    address payable public removedCharity;

    function setUp() public {
        // Set up test addresses
        owner = makeAddr("owner");
        donor1 = makeAddr("donor1");
        donor2 = makeAddr("donor2");
        charity1 = payable(makeAddr("charity1"));
        charity2 = payable(makeAddr("charity2"));
        charity3 = payable(makeAddr("charity3"));
        inactiveCharity = payable(makeAddr("inactiveCharity"));
        removedCharity = payable(makeAddr("removedCharity"));
        
        // Deploy contract with owner
        vm.prank(owner);
        router = new CharityRouter(owner);
        
        // Add test charities
        vm.startPrank(owner);
        router.addCharity("Red Cross", charity1);
        router.addCharity("UNICEF", charity2);
        router.addCharity("Save the Children", charity3);
        router.addCharity("Inactive Charity", inactiveCharity);
        router.addCharity("To Be Removed", removedCharity);
        
        // Deactivate one charity
        router.setCharityStatus(inactiveCharity, false);
        
        // Remove one charity
        router.removeCharity(removedCharity);
        vm.stopPrank();
        
        // Give donors some ETH and make some test donations
        vm.deal(donor1, 10 ether);
        vm.deal(donor2, 10 ether);
        
        // Make various donations to create statistics
        vm.prank(donor1);
        router.donate{value: 2 ether}(charity1);
        
        vm.prank(donor2);
        router.donateByName{value: 1 ether}("UNICEF");
        
        vm.prank(donor1);
        router.donate{value: 3 ether}(charity1);
        
        vm.prank(donor2);
        router.donateByName{value: 0.5 ether}("Save the Children");
    }

    // ===== getAllCharities() TESTS =====

    function testGetAllCharities() public view {
        address[] memory allCharities = router.getAllCharities();
        
        // Should return all 5 addresses (including removed)
        assertEq(allCharities.length, 5);
        
        // Verify addresses are in order of addition
        assertEq(allCharities[0], charity1);
        assertEq(allCharities[1], charity2);
        assertEq(allCharities[2], charity3);
        assertEq(allCharities[3], inactiveCharity);
        assertEq(allCharities[4], removedCharity);
    }

    function testGetAllCharitiesAfterAddingMore() public {
        // Add more charities
        address payable newCharity1 = payable(makeAddr("newCharity1"));
        address payable newCharity2 = payable(makeAddr("newCharity2"));
        
        vm.startPrank(owner);
        router.addCharity("New Charity 1", newCharity1);
        router.addCharity("New Charity 2", newCharity2);
        vm.stopPrank();
        
        address[] memory allCharities = router.getAllCharities();
        
        // Should now have 7 charities total
        assertEq(allCharities.length, 7);
        
        // New charities should be at the end
        assertEq(allCharities[5], newCharity1);
        assertEq(allCharities[6], newCharity2);
    }

    function testGetAllCharitiesEmptyContract() public {
        // Deploy a new empty contract
        vm.prank(owner);
        CharityRouter emptyRouter = new CharityRouter(owner);
        
        address[] memory allCharities = emptyRouter.getAllCharities();
        assertEq(allCharities.length, 0);
    }

    // ===== getCharityStats() TESTS =====

    function testGetCharityStatsActive() public view {
        (
            string memory name,
            bool isActive,
            uint256 totalEthReceived,
            uint256 donationCount,
            uint256 registeredAt
        ) = router.getCharityStats(charity1);
        
        assertEq(name, "Red Cross");
        assertTrue(isActive);
        assertEq(totalEthReceived, 5 ether); // 2 + 3 from donations
        assertEq(donationCount, 2);
        assertGt(registeredAt, 0);
    }

    function testGetCharityStatsInactive() public view {
        (
            string memory name,
            bool isActive,
            uint256 totalEthReceived,
            uint256 donationCount,
            uint256 registeredAt
        ) = router.getCharityStats(inactiveCharity);
        
        assertEq(name, "Inactive Charity");
        assertFalse(isActive);
        assertEq(totalEthReceived, 0); // No donations made
        assertEq(donationCount, 0);
        assertGt(registeredAt, 0);
    }

    function testGetCharityStatsRemoved() public view {
        (
            string memory name,
            bool isActive,
            uint256 totalEthReceived,
            uint256 donationCount,
            uint256 registeredAt
        ) = router.getCharityStats(removedCharity);
        
        assertEq(name, "To Be Removed");
        assertFalse(isActive);
        assertEq(totalEthReceived, 0);
        assertEq(donationCount, 0);
        assertGt(registeredAt, 0);
    }

    function testGetCharityStatsNonExistent() public {
        address nonExistent = makeAddr("nonExistent");
        
        (
            string memory name,
            bool isActive,
            uint256 totalEthReceived,
            uint256 donationCount,
            uint256 registeredAt
        ) = router.getCharityStats(nonExistent);
        
        // Should return default values
        assertEq(name, "");
        assertFalse(isActive);
        assertEq(totalEthReceived, 0);
        assertEq(donationCount, 0);
        assertEq(registeredAt, 0);
    }

    function testGetCharityStatsAfterDonations() public {
        // Make additional donations to charity2
        vm.prank(donor1);
        router.donate{value: 1.5 ether}(charity2);
        
        vm.prank(donor2);
        router.donate{value: 2.5 ether}(charity2);
        
        (
            string memory name,
            bool isActive,
            uint256 totalEthReceived,
            uint256 donationCount,
            uint256 registeredAt
        ) = router.getCharityStats(charity2);
        
        assertEq(name, "UNICEF");
        assertTrue(isActive);
        assertEq(totalEthReceived, 5 ether); // 1 + 1.5 + 2.5
        assertEq(donationCount, 3); // Original 1 + new 2
        assertGt(registeredAt, 0);
    }

    // ===== getTotalStats() TESTS =====

    function testGetTotalStatsBasic() public view {
        (
            uint256 totalCharities,
            uint256 activeCharities,
            uint256 totalDonations,
            uint256 totalEthRouted,
            uint256 averageDonationSize
        ) = router.getTotalStats();
        
        assertEq(totalCharities, 5); // All registered charities
        assertEq(activeCharities, 3); // Only active ones (Red Cross, UNICEF, Save the Children)
        assertEq(totalDonations, 4); // 4 donations made in setup
        assertEq(totalEthRouted, 6.5 ether); // 2 + 1 + 3 + 0.5
        assertEq(averageDonationSize, 1.625 ether); // 6.5 / 4
    }

    function testGetTotalStatsAfterMoreDonations() public {
        // Make more donations
        vm.prank(donor1);
        router.donate{value: 1 ether}(charity2);
        
        vm.prank(donor2);
        router.donate{value: 2 ether}(charity3);
        
        (
            uint256 totalCharities,
            uint256 activeCharities,
            uint256 totalDonations,
            uint256 totalEthRouted,
            uint256 averageDonationSize
        ) = router.getTotalStats();
        
        assertEq(totalCharities, 5);
        assertEq(activeCharities, 3);
        assertEq(totalDonations, 6); // 4 + 2 new
        assertEq(totalEthRouted, 9.5 ether); // 6.5 + 3
        assertEq(averageDonationSize, 1583333333333333333); // 9.5 / 6 (in wei)
    }

    function testGetTotalStatsAfterAddingCharity() public {
        // Add a new charity
        address payable newCharity = payable(makeAddr("newCharity"));
        vm.prank(owner);
        router.addCharity("New Charity", newCharity);
        
        (
            uint256 totalCharities,
            uint256 activeCharities,
            uint256 totalDonations,
            uint256 totalEthRouted,
            uint256 averageDonationSize
        ) = router.getTotalStats();
        
        assertEq(totalCharities, 6); // 5 + 1 new
        assertEq(activeCharities, 4); // 3 + 1 new active
        assertEq(totalDonations, 4); // No new donations
        assertEq(totalEthRouted, 6.5 ether); // No change
        assertEq(averageDonationSize, 1.625 ether); // Same average
    }

    function testGetTotalStatsAfterDeactivating() public {
        // Deactivate an active charity
        vm.prank(owner);
        router.setCharityStatus(charity1, false);
        
        (
            uint256 totalCharities,
            uint256 activeCharities,
            uint256 totalDonations,
            uint256 totalEthRouted,
            uint256 averageDonationSize
        ) = router.getTotalStats();
        
        assertEq(totalCharities, 5); // Same total
        assertEq(activeCharities, 2); // One less active (only UNICEF, Save the Children)
        assertEq(totalDonations, 4); // No change in donations
        assertEq(totalEthRouted, 6.5 ether); // No change
        assertEq(averageDonationSize, 1.625 ether); // Same average
    }

    function testGetTotalStatsEmptyContract() public {
        // Deploy empty contract
        vm.prank(owner);
        CharityRouter emptyRouter = new CharityRouter(owner);
        
        (
            uint256 totalCharities,
            uint256 activeCharities,
            uint256 totalDonations,
            uint256 totalEthRouted,
            uint256 averageDonationSize
        ) = emptyRouter.getTotalStats();
        
        assertEq(totalCharities, 0);
        assertEq(activeCharities, 0);
        assertEq(totalDonations, 0);
        assertEq(totalEthRouted, 0);
        assertEq(averageDonationSize, 0); // Division by zero handled
    }

    function testGetTotalStatsZeroDonationsButCharitiesExist() public {
        // Deploy new contract and add charities but no donations
        vm.prank(owner);
        CharityRouter newRouter = new CharityRouter(owner);
        
        vm.startPrank(owner);
        newRouter.addCharity("Test Charity 1", payable(makeAddr("test1")));
        newRouter.addCharity("Test Charity 2", payable(makeAddr("test2")));
        vm.stopPrank();
        
        (
            uint256 totalCharities,
            uint256 activeCharities,
            uint256 totalDonations,
            uint256 totalEthRouted,
            uint256 averageDonationSize
        ) = newRouter.getTotalStats();
        
        assertEq(totalCharities, 2);
        assertEq(activeCharities, 2);
        assertEq(totalDonations, 0);
        assertEq(totalEthRouted, 0);
        assertEq(averageDonationSize, 0); // No division by zero
    }

    // ===== isValidCharity() TESTS =====

    function testIsValidCharityActive() public view {
        assertTrue(router.isValidCharity(charity1));
        assertTrue(router.isValidCharity(charity2));
        assertTrue(router.isValidCharity(charity3));
    }

    function testIsValidCharityInactive() public view {
        assertFalse(router.isValidCharity(inactiveCharity));
    }

    function testIsValidCharityRemoved() public view {
        assertFalse(router.isValidCharity(removedCharity));
    }

    function testIsValidCharityNonExistent() public {
        address nonExistent = makeAddr("nonExistent");
        assertFalse(router.isValidCharity(nonExistent));
    }

    function testIsValidCharityAfterStatusChange() public {
        // Initially valid
        assertTrue(router.isValidCharity(charity1));
        
        // Deactivate
        vm.prank(owner);
        router.setCharityStatus(charity1, false);
        assertFalse(router.isValidCharity(charity1));
        
        // Reactivate
        vm.prank(owner);
        router.setCharityStatus(charity1, true);
        assertTrue(router.isValidCharity(charity1));
    }

    function testIsValidCharityAfterRemoval() public {
        // Initially valid
        assertTrue(router.isValidCharity(charity1));
        
        // Remove charity
        vm.prank(owner);
        router.removeCharity(charity1);
        
        // Should no longer be valid
        assertFalse(router.isValidCharity(charity1));
    }

    // ===== isValidCharityName() TESTS =====

    function testIsValidCharityNameActive() public view {
        assertTrue(router.isValidCharityName("Red Cross"));
        assertTrue(router.isValidCharityName("UNICEF"));
        assertTrue(router.isValidCharityName("Save the Children"));
    }

    function testIsValidCharityNameInactive() public view {
        assertFalse(router.isValidCharityName("Inactive Charity"));
    }

    function testIsValidCharityNameRemoved() public view {
        assertFalse(router.isValidCharityName("To Be Removed"));
    }

    function testIsValidCharityNameNonExistent() public view {
        assertFalse(router.isValidCharityName("Non Existent Charity"));
        assertFalse(router.isValidCharityName(""));
    }

    function testIsValidCharityNameAfterUpdate() public {
        // Initially valid
        assertTrue(router.isValidCharityName("Red Cross"));
        
        // Update name
        vm.prank(owner);
        router.updateCharity(charity1, "American Red Cross");
        
        // Old name should be invalid, new name should be valid
        assertFalse(router.isValidCharityName("Red Cross"));
        assertTrue(router.isValidCharityName("American Red Cross"));
    }

    function testIsValidCharityNameAfterStatusChange() public {
        // Initially valid
        assertTrue(router.isValidCharityName("Red Cross"));
        
        // Deactivate
        vm.prank(owner);
        router.setCharityStatus(charity1, false);
        assertFalse(router.isValidCharityName("Red Cross"));
        
        // Reactivate
        vm.prank(owner);
        router.setCharityStatus(charity1, true);
        assertTrue(router.isValidCharityName("Red Cross"));
    }

    function testIsValidCharityNameCaseSensitive() public view {
        assertTrue(router.isValidCharityName("Red Cross"));
        assertFalse(router.isValidCharityName("red cross"));
        assertFalse(router.isValidCharityName("RED CROSS"));
        assertFalse(router.isValidCharityName("Red cross"));
    }

    // ===== INTEGRATION TESTS =====

    function testViewFunctionsConsistency() public view {
        // Test that different view functions return consistent data
        
        // Get all charities
        address[] memory allCharities = router.getAllCharities();
        
        // Check each charity individually
        uint256 activeCount = 0;
        for (uint256 i = 0; i < allCharities.length; i++) {
            address charityAddr = allCharities[i];
            
            // Get charity stats
            (
                string memory name,
                bool isActive,
                , // totalEthReceived - unused
                , // donationCount - unused  
                  // registeredAt - unused
            ) = router.getCharityStats(charityAddr);
            
            // Check consistency with isValidCharity
            assertEq(router.isValidCharity(charityAddr), isActive && charityAddr != address(0));
            
            // Check consistency with isValidCharityName (if name exists)
            if (bytes(name).length > 0 && charityAddr != address(0)) {
                assertEq(router.isValidCharityName(name), isActive);
            }
            
            // Count active charities
            if (isActive && charityAddr != address(0)) {
                activeCount++;
            }
        }
        
        // Check consistency with getTotalStats
        (
            uint256 totalCharities,
            uint256 activeCharities,
            ,,  // totalDonations, totalEthRouted - unused
              // averageDonationSize - unused
        ) = router.getTotalStats();
        
        assertEq(totalCharities, allCharities.length);
        assertEq(activeCharities, activeCount);
    }

    function testViewFunctionsAfterComplexOperations() public {
        // Perform complex operations and verify view functions still work correctly
        
        // Add new charity
        address payable newCharity = payable(makeAddr("complexTestCharity"));
        vm.prank(owner);
        router.addCharity("Complex Test Charity", newCharity);
        
        // Make donations
        vm.prank(donor1);
        router.donate{value: 1 ether}(newCharity);
        
        vm.prank(donor2);
        router.donateByName{value: 2 ether}("Complex Test Charity");
        
        // Update charity name
        vm.prank(owner);
        router.updateCharity(newCharity, "Updated Complex Charity");
        
        // Deactivate and reactivate
        vm.startPrank(owner);
        router.setCharityStatus(newCharity, false);
        router.setCharityStatus(newCharity, true);
        vm.stopPrank();
        
        // Verify all view functions work correctly
        address[] memory allCharities = router.getAllCharities();
        assertEq(allCharities.length, 6); // 5 original + 1 new
        
        (
            string memory name,
            bool isActive,
            uint256 totalEthReceived,
            uint256 donationCount,
            uint256 registeredAt
        ) = router.getCharityStats(newCharity);
        
        assertEq(name, "Updated Complex Charity");
        assertTrue(isActive);
        assertEq(totalEthReceived, 3 ether);
        assertEq(donationCount, 2);
        assertGt(registeredAt, 0);
        
        // Check validation functions
        assertTrue(router.isValidCharity(newCharity));
        assertTrue(router.isValidCharityName("Updated Complex Charity"));
        assertFalse(router.isValidCharityName("Complex Test Charity")); // Old name
        
        // Check total stats
        (
            uint256 totalCharities,
            uint256 activeCharities,
            uint256 totalDonations,
            uint256 totalEthRouted,
            uint256 averageDonationSize
        ) = router.getTotalStats();
        
        assertEq(totalCharities, 6);
        assertEq(activeCharities, 4); // 3 original + 1 new
        assertEq(totalDonations, 6); // 4 original + 2 new
        assertEq(totalEthRouted, 9.5 ether); // 6.5 original + 3 new
        assertEq(averageDonationSize, 1583333333333333333); // 9.5 / 6 in wei
    }

    function testViewFunctionsGasEfficiency() public view {
        // Test that view functions are reasonably gas efficient
        
        // These should be view functions that don't modify state
        uint256 gasBefore;
        uint256 gasAfter;
        
        // Test getAllCharities
        gasBefore = gasleft();
        router.getAllCharities();
        gasAfter = gasleft();
        uint256 getAllCharitiesGas = gasBefore - gasAfter;
        
        // Test getCharityStats
        gasBefore = gasleft();
        router.getCharityStats(charity1);
        gasAfter = gasleft();
        uint256 getCharityStatsGas = gasBefore - gasAfter;
        
        // Test getTotalStats (most expensive due to loop)
        gasBefore = gasleft();
        router.getTotalStats();
        gasAfter = gasleft();
        uint256 getTotalStatsGas = gasBefore - gasAfter;
        
        // Test validation functions
        gasBefore = gasleft();
        router.isValidCharity(charity1);
        gasAfter = gasleft();
        uint256 isValidCharityGas = gasBefore - gasAfter;
        
        gasBefore = gasleft();
        router.isValidCharityName("Red Cross");
        gasAfter = gasleft();
        uint256 isValidCharityNameGas = gasBefore - gasAfter;
        
        // These are just sanity checks - actual gas usage will vary
        // but they should all be reasonable for view functions
        console.log("getAllCharities gas:", getAllCharitiesGas);
        console.log("getCharityStats gas:", getCharityStatsGas);
        console.log("getTotalStats gas:", getTotalStatsGas);
        console.log("isValidCharity gas:", isValidCharityGas);
        console.log("isValidCharityName gas:", isValidCharityNameGas);
        
        // Basic sanity checks - view functions should be relatively cheap
        assertTrue(getAllCharitiesGas < 100000);
        assertTrue(getCharityStatsGas < 50000);
        assertTrue(getTotalStatsGas < 200000); // Higher due to loop
        assertTrue(isValidCharityGas < 50000);
        assertTrue(isValidCharityNameGas < 50000);
    }

    function testAllViewFunctionsPreviousFunctionalityStillWorks() public {
        // Verify that adding view functions doesn't break existing functionality
        
        // Test charity management still works
        address payable testCharity = payable(makeAddr("testCharity"));
        vm.prank(owner);
        router.addCharity("Test Charity", testCharity);
        
        // Test donations still work
        vm.prank(donor1);
        router.donate{value: 1 ether}(testCharity);
        
        vm.prank(donor2);
        router.donateByName{value: 0.5 ether}("Test Charity");
        
        // Test all view functions work with new data
        address[] memory allCharities = router.getAllCharities();
        assertEq(allCharities.length, 6);
        
        (,bool isActive, uint256 totalEthReceived, uint256 donationCount,) = router.getCharityStats(testCharity);
        assertTrue(isActive);
        assertEq(totalEthReceived, 1.5 ether);
        assertEq(donationCount, 2);
        
        assertTrue(router.isValidCharity(testCharity));
        assertTrue(router.isValidCharityName("Test Charity"));
        
        (,,uint256 totalDonations, uint256 totalEthRouted,) = router.getTotalStats();
        assertEq(totalDonations, 6); // 4 original + 2 new
        assertEq(totalEthRouted, 8 ether); // 6.5 original + 1.5 new
    }
}
