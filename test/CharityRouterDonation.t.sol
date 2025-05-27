// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/CharityRouter.sol";

contract CharityRouterDonationTest is Test {
    CharityRouter public router;
    address public owner;
    address public donor1;
    address public donor2;
    address payable public charity1;
    address payable public charity2;
    address payable public inactiveCharity;

    // Event declarations for testing
    event DonationRouted(
        uint256 indexed donationId, address indexed donor, address indexed charity, uint256 amount, string charityName
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

    // ===== DONATION INFRASTRUCTURE TESTS (Step 6) =====

    function testDonationCountersInitialization() public view {
        // Test donation counters initialize correctly
        assertEq(router.totalDonations(), 0);
        assertEq(router.nextDonationId(), 1); // Should start at 1
        assertEq(router.totalEthRouted(), 0);

        // Test donation stats function
        (uint256 totalDonations_, uint256 totalEthRouted_, uint256 nextDonationId_) = router.getDonationStats();
        assertEq(totalDonations_, 0);
        assertEq(totalEthRouted_, 0);
        assertEq(nextDonationId_, 1);
    }

    function testDonationEventStructure() public {
        // Test event structure by making a donation
        uint256 donationAmount = 1 ether;

        vm.expectEmit(true, true, true, true);
        emit DonationRouted(1, donor1, charity1, donationAmount, "Red Cross");

        vm.prank(donor1);
        router.donate{value: donationAmount}(charity1);
    }

    // ===== CORE DONATION FUNCTIONALITY TESTS (Step 7) =====

    function testSuccessfulDonation() public {
        uint256 donationAmount = 1 ether;
        uint256 initialCharityBalance = charity1.balance;
        uint256 initialContractBalance = address(router).balance;

        // Make donation
        vm.prank(donor1);
        router.donate{value: donationAmount}(charity1);

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

    function testMultipleDonations() public {
        uint256 donation1 = 1 ether;
        uint256 donation2 = 0.5 ether;
        uint256 donation3 = 2 ether;

        // First donation
        vm.prank(donor1);
        router.donate{value: donation1}(charity1);

        // Second donation to same charity
        vm.prank(donor2);
        router.donate{value: donation2}(charity1);

        // Third donation to different charity
        vm.prank(donor1);
        router.donate{value: donation3}(charity2);

        // Verify global statistics
        assertEq(router.totalDonations(), 3);
        assertEq(router.nextDonationId(), 4);
        assertEq(router.totalEthRouted(), donation1 + donation2 + donation3);

        // Verify charity1 statistics
        CharityRouter.Charity memory charity1Stats = router.getCharityByAddress(charity1);
        assertEq(charity1Stats.totalEthReceived, donation1 + donation2);
        assertEq(charity1Stats.donationCount, 2);
        assertEq(charity1.balance, donation1 + donation2);

        // Verify charity2 statistics
        CharityRouter.Charity memory charity2Stats = router.getCharityByAddress(charity2);
        assertEq(charity2Stats.totalEthReceived, donation3);
        assertEq(charity2Stats.donationCount, 1);
        assertEq(charity2.balance, donation3);
    }

    function testDonationEventEmission() public {
        uint256 donationAmount = 1.5 ether;

        // Expect specific event emission
        vm.expectEmit(true, true, true, true);
        emit DonationRouted(1, donor1, charity1, donationAmount, "Red Cross");

        vm.prank(donor1);
        router.donate{value: donationAmount}(charity1);
    }

    function testMultipleDonationEvents() public {
        uint256 donation1 = 1 ether;
        uint256 donation2 = 2 ether;

        // First donation - ID should be 1
        vm.expectEmit(true, true, true, true);
        emit DonationRouted(1, donor1, charity1, donation1, "Red Cross");

        vm.prank(donor1);
        router.donate{value: donation1}(charity1);

        // Second donation - ID should be 2
        vm.expectEmit(true, true, true, true);
        emit DonationRouted(2, donor2, charity2, donation2, "UNICEF");

        vm.prank(donor2);
        router.donate{value: donation2}(charity2);
    }

    function testZeroDonationRejection() public {
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.EmptyDonation.selector);
        router.donate{value: 0}(charity1);

        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testDonationToNonExistentCharity() public {
        address nonExistentCharity = makeAddr("nonExistent");

        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donate{value: 1 ether}(nonExistentCharity);

        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testDonationToInactiveCharity() public {
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.InactiveCharity.selector);
        router.donate{value: 1 ether}(inactiveCharity);

        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testDonationToRemovedCharity() public {
        // Remove a charity
        vm.prank(owner);
        router.removeCharity(charity1);

        // Try to donate to removed charity
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.donate{value: 1 ether}(charity1);

        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testReentrancyProtection() public {
        // Deploy a malicious contract that tries to reenter
        MaliciousCharity malicious = new MaliciousCharity(address(router));

        // Add malicious contract as charity
        vm.prank(owner);
        router.addCharity("Malicious", payable(address(malicious)));

        // Give malicious contract some initial balance for gas
        vm.deal(address(malicious), 1 ether);

        // Try to donate - should not allow reentrancy
        vm.prank(donor1);
        vm.expectRevert(); // Should revert due to reentrancy guard
        router.donate{value: 1 ether}(payable(address(malicious)));
    }

    function testDirectETHTransfer() public {
        uint256 donationAmount = 1 ether;
        uint256 initialBalance = charity1.balance;

        vm.prank(donor1);
        router.donate{value: donationAmount}(charity1);

        // Verify ETH was transferred directly
        assertEq(charity1.balance, initialBalance + donationAmount);

        // Verify contract holds no ETH
        assertEq(address(router).balance, 0);
    }

    function testContractNeverHoldsFunds() public {
        // Make multiple donations
        vm.prank(donor1);
        router.donate{value: 1 ether}(charity1);

        vm.prank(donor2);
        router.donate{value: 0.5 ether}(charity2);

        vm.prank(donor1);
        router.donate{value: 2 ether}(charity1);

        // Contract should never hold any ETH
        assertEq(address(router).balance, 0);

        // But total routed should be tracked
        assertEq(router.totalEthRouted(), 3.5 ether);
    }

    function testDonationValidationHelpers() public {
        // Test that validation works correctly

        // Valid charity should not revert when called directly
        // (We can't call internal functions directly, but we test via donate)

        // Valid donation should succeed
        vm.prank(donor1);
        router.donate{value: 1 ether}(charity1);

        // Invalid donations should fail (tested above)
        // This confirms our validation helpers work correctly
    }

    function testLargeDonation() public {
        uint256 largeDonation = 100 ether;
        vm.deal(donor1, largeDonation);

        vm.prank(donor1);
        router.donate{value: largeDonation}(charity1);

        // Verify large donation handled correctly
        assertEq(charity1.balance, largeDonation);
        assertEq(router.totalEthRouted(), largeDonation);

        CharityRouter.Charity memory charity = router.getCharityByAddress(charity1);
        assertEq(charity.totalEthReceived, largeDonation);
    }

    function testSmallDonation() public {
        uint256 smallDonation = 1 wei;

        vm.prank(donor1);
        router.donate{value: smallDonation}(charity1);

        // Verify small donation handled correctly
        assertEq(charity1.balance, smallDonation);
        assertEq(router.totalEthRouted(), smallDonation);

        CharityRouter.Charity memory charity = router.getCharityByAddress(charity1);
        assertEq(charity.totalEthReceived, smallDonation);
    }

    function testDonationIdSequencing() public {
        // Make several donations and verify IDs increment correctly
        uint256 donationAmount = 0.5 ether;

        vm.expectEmit(true, true, true, true);
        emit DonationRouted(1, donor1, charity1, donationAmount, "Red Cross");
        vm.prank(donor1);
        router.donate{value: donationAmount}(charity1);

        vm.expectEmit(true, true, true, true);
        emit DonationRouted(2, donor2, charity2, donationAmount, "UNICEF");
        vm.prank(donor2);
        router.donate{value: donationAmount}(charity2);

        vm.expectEmit(true, true, true, true);
        emit DonationRouted(3, donor1, charity2, donationAmount, "UNICEF");
        vm.prank(donor1);
        router.donate{value: donationAmount}(charity2);

        // Verify next ID is correct
        assertEq(router.nextDonationId(), 4);
    }

    function testStatisticsAccuracy() public {
        // Make various donations and verify all statistics are accurate
        uint256[] memory donations = new uint256[](5);
        donations[0] = 1 ether;
        donations[1] = 0.5 ether;
        donations[2] = 2.5 ether;
        donations[3] = 0.1 ether;
        donations[4] = 3 ether;

        uint256 totalExpected = 0;
        for (uint256 i = 0; i < donations.length; i++) {
            totalExpected += donations[i];
        }

        // Make donations
        vm.prank(donor1);
        router.donate{value: donations[0]}(charity1);

        vm.prank(donor2);
        router.donate{value: donations[1]}(charity2);

        vm.prank(donor1);
        router.donate{value: donations[2]}(charity1);

        vm.prank(donor2);
        router.donate{value: donations[3]}(charity1);

        vm.prank(donor1);
        router.donate{value: donations[4]}(charity2);

        // Verify global statistics
        assertEq(router.totalDonations(), 5);
        assertEq(router.totalEthRouted(), totalExpected);
        assertEq(router.nextDonationId(), 6);

        // Verify charity1 specific statistics
        uint256 charity1Expected = donations[0] + donations[2] + donations[3];
        CharityRouter.Charity memory charity1Stats = router.getCharityByAddress(charity1);
        assertEq(charity1Stats.totalEthReceived, charity1Expected);
        assertEq(charity1Stats.donationCount, 3);

        // Verify charity2 specific statistics
        uint256 charity2Expected = donations[1] + donations[4];
        CharityRouter.Charity memory charity2Stats = router.getCharityByAddress(charity2);
        assertEq(charity2Stats.totalEthReceived, charity2Expected);
        assertEq(charity2Stats.donationCount, 2);
    }

    function testTransferFailureHandling() public {
        // Create a contract that rejects ETH transfers
        RejectingContract rejecter = new RejectingContract();

        // Add rejecting contract as charity
        vm.prank(owner);
        router.addCharity("Rejecting Charity", payable(address(rejecter)));

        // Try to donate - should fail with TransferFailed
        vm.prank(donor1);
        vm.expectRevert(CharityRouter.TransferFailed.selector);
        router.donate{value: 1 ether}(payable(address(rejecter)));

        // Verify no statistics were updated
        assertEq(router.totalDonations(), 0);
        assertEq(router.totalEthRouted(), 0);
    }

    function testDonationStatsFunction() public {
        // Make some donations
        vm.prank(donor1);
        router.donate{value: 1 ether}(charity1);

        vm.prank(donor2);
        router.donate{value: 2 ether}(charity2);

        // Test stats function returns correct values
        (uint256 totalDonations_, uint256 totalEthRouted_, uint256 nextDonationId_) = router.getDonationStats();

        assertEq(totalDonations_, 2);
        assertEq(totalEthRouted_, 3 ether);
        assertEq(nextDonationId_, 3);
    }

    function testPreviousFunctionalityStillWorks() public {
        // Verify all previous functionality still works after adding donations

        // Test charity management still works
        vm.prank(owner);
        router.addCharity("New Charity", payable(makeAddr("newCharity")));
        assertEq(router.getCharityCount(), 4); // 3 from setup + 1 new

        // Test charity updates still work
        vm.prank(owner);
        router.updateCharity(charity1, "Updated Red Cross");

        CharityRouter.Charity memory updatedCharity = router.getCharityByAddress(charity1);
        assertEq(updatedCharity.name, "Updated Red Cross");

        // Test donations still work after management operations
        vm.prank(donor1);
        router.donate{value: 1 ether}(charity1);

        assertEq(router.totalDonations(), 1);
        assertEq(charity1.balance, 1 ether);
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
            // Try to reenter the donate function
            router.donate{value: 0.1 ether}(payable(address(this)));
        }
    }
}

// Helper contract for testing transfer failure handling
contract RejectingContract {
    // This contract rejects all ETH transfers
    receive() external payable {
        revert("I reject your ETH!");
    }
}
