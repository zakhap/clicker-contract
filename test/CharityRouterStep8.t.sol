// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/CharityRouter.sol";

contract CharityRouterStep8Test is Test {
    CharityRouter public router;
    address public owner;
    address public donor1;
    address public donor2;
    address payable public charity1;
    address payable public charity2;
    address payable public inactiveCharity;

    // Event declarations for testing
    event DonationRouted(
        uint256 indexed donationId,
        address indexed donor,
        address indexed charity,
        uint256 amount,
        string charityName
    );

    function setUp() public {
        // Set up test addresses
        owner = makeAddr("owner");
        donor1 = makeAddr("donor1");
        donor2 = makeAddr("donor2");
        charity1 = payable(makeAddr("charity1"));
        charity2 = payable(makeAddr("charity2"));
        inactiveCharity = payable(makeAddr("inactiveCharity"));
        
        // Deploy contract with owner
        vm.prank(owner);
        router = new CharityRouter(owner);
        
        // Add test charities
        vm.startPrank(owner);
        router.addCharity("Red Cross", charity1);
        router.addCharity("UNICEF", charity2);
        router.addCharity("Inactive Charity", inactiveCharity);
        
        // Deactivate one charity for testing
        router.setCharityStatus(inactiveCharity, false);
        vm.stopPrank();
        
        // Give donors some ETH
        vm.deal(donor1, 10 ether);
        vm.deal(donor2, 5 ether);
    }

    // ===== STEP 8 TESTS: Donation by Name Functionality =====

    function testStep8_SuccessfulDonationByName() public {
        uint256 donationAmount = 1 ether;
        uint256 initialCharityBalance = charity1.balance;
        uint256 initialContractBalance = address(router).balance;
        
        // Make donation by name
        vm.prank(donor1);
        router.donateByName{value: donationAmount}("Red Cross");
        
        // Verify ETH was transferred to charity immediately
        assertEq(charity1.balance, initialCharityBalance + donationAmount);
        
        // Verify contract holds no funds
        assertEq(address(router).balance, initialContractBalance);
        
        // Verify donation statistics updated
        assertEq(router.totalDonations(), 1);
        assertEq(router.nextDonationId(), 2); // Should increment
        assertEq(router.totalEthRouted(), donationAmount);
        
        // Verify charity statistics updated
        CharityRouter.Charity memory charity = router.getCharityByAddress(charity1);
        assertEq(charity.totalEthReceived, donationAmount);
        assertEq(charity.donationCount, 1);
    }

    function testStep8_DonationByNameEventEmission() public {
        uint256 donationAmount = 1.5 ether;
        
        // Expect specific event emission
        vm.expectEmit(true, true, true, true);
        emit DonationRouted(1, donor1, charity1, donationAmount, "Red Cross");
        
        vm.prank(donor1);
        router.donateByName{value: donationAmount}("Red Cross");
    }

    function testStep8_DonationByNameMultipleCharities() public {
        uint256 donation1 = 1 ether;
        uint256 donation2 = 2 ether;
        
        // First donation by name
        vm.prank(donor1);
        router.donateByName{value: donation1}("Red Cross");
        
        // Second donation by name to different charity
        vm.prank(donor2);
        router.donateByName{value: donation2}("UNICEF");
        
        // Verify both charities received correct amounts
        assertEq(charity1.balance, donation1);
        assertEq(charity2.balance, donation2);
        
        // Verify statistics
        assertEq(router.totalDonations(), 2);
        assertEq(router.totalEthRouted(), donation1 + donation2);
        
        // Verify individual charity statistics
        CharityRouter.Charity memory charity1Stats = router.getCharityByAddress(charity1);
        assertEq(charity1Stats.totalEthReceived, donation1);
        assertEq(charity1Stats.donationCount, 1);
        
        CharityRouter.Charity memory charity2Stats = router.getCharityByAddress(charity2);
        assertEq(charity2Stats.totalEthReceived, donation2);
        assertEq(charity2Stats.donationCount, 1);
    }

    function testStep8_DonationByInvalidName() public {
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: 1 ether}("NonExistent Charity");
        
        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testStep8_DonationByNameToInactiveCharity() public {
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.InactiveCharity.selector);
        router.donateByName{value: 1 ether}("Inactive Charity");
        
        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testStep8_ZeroDonationByName() public {
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.EmptyDonation.selector);
        router.donateByName{value: 0}("Red Cross");
        
        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testStep8_DonationByNameToRemovedCharity() public {
        // Remove a charity
        vm.prank(owner);
        router.removeCharity(charity1);
        
        // Try to donate to removed charity by name
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: 1 ether}("Red Cross");
        
        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testStep8_NameResolutionCorrectness() public {
        // Add multiple charities with different names
        address payable charity3 = payable(makeAddr("charity3"));
        address payable charity4 = payable(makeAddr("charity4"));
        
        vm.startPrank(owner);
        router.addCharity("Save the Children", charity3);
        router.addCharity("Doctors Without Borders", charity4);
        vm.stopPrank();
        
        uint256 donationAmount = 0.5 ether;
        
        // Donate to each charity by name
        vm.prank(donor1);
        router.donateByName{value: donationAmount}("Save the Children");
        
        vm.prank(donor2);
        router.donateByName{value: donationAmount}("Doctors Without Borders");
        
        // Verify correct charities received the donations
        assertEq(charity3.balance, donationAmount);
        assertEq(charity4.balance, donationAmount);
        
        // Verify other charities didn't receive anything
        assertEq(charity1.balance, 0);
        assertEq(charity2.balance, 0);
    }

    function testStep8_DonationByNameAfterCharityUpdate() public {
        // Update charity name
        vm.prank(owner);
        router.updateCharity(charity1, "American Red Cross");
        
        uint256 donationAmount = 1 ether;
        
        // Donation with old name should fail
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: donationAmount}("Red Cross");
        
        // Donation with new name should succeed
        vm.prank(donor1);
        router.donateByName{value: donationAmount}("American Red Cross");
        
        // Verify donation went through
        assertEq(charity1.balance, donationAmount);
        assertEq(router.totalDonations(), 1);
    }

    function testStep8_BothDonationMethodsWorkIdentically() public {
        uint256 donationAmount = 1 ether;
        
        // Donate by address
        vm.prank(donor1);
        router.donate{value: donationAmount}(charity1);
        
        // Donate by name to same charity
        vm.prank(donor2);
        router.donateByName{value: donationAmount}("Red Cross");
        
        // Both should have identical results
        assertEq(charity1.balance, 2 * donationAmount);
        assertEq(router.totalDonations(), 2);
        assertEq(router.totalEthRouted(), 2 * donationAmount);
        
        // Charity statistics should reflect both donations
        CharityRouter.Charity memory charity = router.getCharityByAddress(charity1);
        assertEq(charity.totalEthReceived, 2 * donationAmount);
        assertEq(charity.donationCount, 2);
    }

    function testStep8_DonationByNameReentrancyProtection() public {
        // Deploy a malicious contract that tries to reenter
        MaliciousCharity malicious = new MaliciousCharity(address(router));
        
        // Add malicious contract as charity
        vm.prank(owner);
        router.addCharity("Malicious Charity", payable(address(malicious)));
        
        // Give malicious contract some initial balance for gas
        vm.deal(address(malicious), 1 ether);
        
        // Try to donate by name - should not allow reentrancy
        vm.prank(donor1);
        vm.expectRevert(); // Should revert due to reentrancy guard
        router.donateByName{value: 1 ether}("Malicious Charity");
    }

    function testStep8_EmptyStringCharityName() public {
        // Try to donate to empty string name
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: 1 ether}("");
        
        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testStep8_CaseSensitiveNameResolution() public {
        // Try donation with different case
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: 1 ether}("red cross"); // lowercase
        
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: 1 ether}("RED CROSS"); // uppercase
        
        // Only exact case should work
        vm.prank(donor1);
        router.donateByName{value: 1 ether}("Red Cross"); // exact case
        
        assertEq(charity1.balance, 1 ether);
    }

    function testStep8_SameValidationLogicAsAddressDonation() public {
        // Test that donateByName uses same validation as donate()
        
        // Test zero donation
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.EmptyDonation.selector);
        router.donateByName{value: 0}("Red Cross");
        
        // Test inactive charity
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.InactiveCharity.selector);
        router.donateByName{value: 1 ether}("Inactive Charity");
        
        // Test non-existent charity
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: 1 ether}("Non Existent");
        
        // Verify no side effects from failed donations
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
        assertEq(charity1.balance, 0);
        assertEq(charity2.balance, 0);
        assertEq(inactiveCharity.balance, 0);
    }

    function testStep8_DonationIdSequencingWithMixedMethods() public {
        // Mix donation by address and by name, verify IDs increment correctly
        uint256 donationAmount = 0.5 ether;
        
        // Donation 1: by address
        vm.expectEmit(true, true, true, true);
        emit DonationRouted(1, donor1, charity1, donationAmount, "Red Cross");
        vm.prank(donor1);
        router.donate{value: donationAmount}(charity1);
        
        // Donation 2: by name
        vm.expectEmit(true, true, true, true);
        emit DonationRouted(2, donor2, charity2, donationAmount, "UNICEF");
        vm.prank(donor2);
        router.donateByName{value: donationAmount}("UNICEF");
        
        // Donation 3: by name again
        vm.expectEmit(true, true, true, true);
        emit DonationRouted(3, donor1, charity1, donationAmount, "Red Cross");
        vm.prank(donor1);
        router.donateByName{value: donationAmount}("Red Cross");
        
        // Verify next ID is correct
        assertEq(router.nextDonationId(), 4);
        assertEq(router.totalDonations(), 3);
    }

    function testStep8_NameResolutionAfterMultipleUpdates() public {
        // Test name resolution after multiple charity name updates
        vm.startPrank(owner);
        
        // Initial update
        router.updateCharity(charity1, "American Red Cross");
        
        // Another update
        router.updateCharity(charity1, "International Red Cross");
        
        vm.stopPrank();
        
        uint256 donationAmount = 1 ether;
        
        // Old names should fail
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: donationAmount}("Red Cross");
        
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donateByName{value: donationAmount}("American Red Cross");
        
        // Current name should work
        vm.prank(donor1);
        router.donateByName{value: donationAmount}("International Red Cross");
        
        assertEq(charity1.balance, donationAmount);
    }

    function testStep8_LargeDonationByName() public {
        uint256 largeDonation = 100 ether;
        vm.deal(donor1, largeDonation);
        
        vm.prank(donor1);
        router.donateByName{value: largeDonation}("Red Cross");
        
        // Verify large donation handled correctly
        assertEq(charity1.balance, largeDonation);
        assertEq(router.totalEthRouted(), largeDonation);
        
        CharityRouter.Charity memory charity = router.getCharityByAddress(charity1);
        assertEq(charity.totalEthReceived, largeDonation);
    }

    function testStep8_SmallDonationByName() public {
        uint256 smallDonation = 1 wei;
        
        vm.prank(donor1);
        router.donateByName{value: smallDonation}("Red Cross");
        
        // Verify small donation handled correctly
        assertEq(charity1.balance, smallDonation);
        assertEq(router.totalEthRouted(), smallDonation);
        
        CharityRouter.Charity memory charity = router.getCharityByAddress(charity1);
        assertEq(charity.totalEthReceived, smallDonation);
    }

    function testStep8_ContractNeverHoldsFundsWithNameDonations() public {
        // Make multiple donations by name
        vm.prank(donor1);
        router.donateByName{value: 1 ether}("Red Cross");
        
        vm.prank(donor2);
        router.donateByName{value: 0.5 ether}("UNICEF");
        
        vm.prank(donor1);
        router.donateByName{value: 2 ether}("Red Cross");
        
        // Contract should never hold any ETH
        assertEq(address(router).balance, 0);
        
        // But total routed should be tracked
        assertEq(router.totalEthRouted(), 3.5 ether);
    }

    function testStep8_DonationStatisticsAccuracy() public {
        // Make various donations by name and verify all statistics are accurate
        uint256[] memory donations = new uint256[](4);
        donations[0] = 1 ether;
        donations[1] = 0.5 ether;
        donations[2] = 2.5 ether;
        donations[3] = 0.1 ether;
        
        uint256 totalExpected = 0;
        for (uint256 i = 0; i < donations.length; i++) {
            totalExpected += donations[i];
        }
        
        // Make donations by name
        vm.prank(donor1);
        router.donateByName{value: donations[0]}("Red Cross");
        
        vm.prank(donor2);
        router.donateByName{value: donations[1]}("UNICEF");
        
        vm.prank(donor1);
        router.donateByName{value: donations[2]}("Red Cross");
        
        vm.prank(donor2);
        router.donateByName{value: donations[3]}("Red Cross");
        
        // Verify global statistics
        assertEq(router.totalDonations(), 4);
        assertEq(router.totalEthRouted(), totalExpected);
        assertEq(router.nextDonationId(), 5);
        
        // Verify charity1 specific statistics
        uint256 charity1Expected = donations[0] + donations[2] + donations[3];
        CharityRouter.Charity memory charity1Stats = router.getCharityByAddress(charity1);
        assertEq(charity1Stats.totalEthReceived, charity1Expected);
        assertEq(charity1Stats.donationCount, 3);
        
        // Verify charity2 specific statistics
        uint256 charity2Expected = donations[1];
        CharityRouter.Charity memory charity2Stats = router.getCharityByAddress(charity2);
        assertEq(charity2Stats.totalEthReceived, charity2Expected);
        assertEq(charity2Stats.donationCount, 1);
    }

    function testStep8_PreviousFunctionalityStillWorks() public {
        // Verify all previous functionality still works after adding donateByName
        
        // Test charity management still works
        vm.prank(owner);
        router.addCharity("New Charity", payable(makeAddr("newCharity")));
        assertEq(router.getCharityCount(), 4); // 3 from setup + 1 new
        
        // Test charity updates still work
        vm.prank(owner);
        router.updateCharity(charity1, "Updated Red Cross");
        
        CharityRouter.Charity memory updatedCharity = router.getCharityByAddress(charity1);
        assertEq(updatedCharity.name, "Updated Red Cross");
        
        // Test both donation methods still work after management operations
        vm.prank(donor1);
        router.donate{value: 1 ether}(charity1);
        
        vm.prank(donor2);
        router.donateByName{value: 0.5 ether}("Updated Red Cross");
        
        assertEq(router.totalDonations(), 2);
        assertEq(charity1.balance, 1.5 ether);
    }
}

// Helper contract for testing reentrancy protection
contract MaliciousCharity {
    CharityRouter public router;
    bool public attacked = false;
    
    constructor(address _router) {
        router = CharityRouter(_router);
    }
    
    receive() external payable {
        if (!attacked) {
            attacked = true;
            // Try to reenter the donateByName function
            router.donateByName{value: 0.1 ether}("Malicious Charity");
        }
    }
}
