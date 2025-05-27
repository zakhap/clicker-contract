// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/CharityRouter.sol";

contract CharityRouterStep5Test is Test {
    CharityRouter public router;
    address public owner;
    address public notOwner;

    // Event declaration for testing
    event CharityAdded(address indexed charityAddress, string name, uint256 timestamp);

    function setUp() public {
        // Set up test addresses
        owner = makeAddr("owner");
        notOwner = makeAddr("notOwner");
        
        // Deploy contract with owner
        vm.prank(owner);
        router = new CharityRouter(owner);
    }

    // ===== STEP 5 TESTS: Batch Charity Registration =====

    function testStep5_SuccessfulBatchAddition() public {
        // Prepare batch data
        string[] memory names = new string[](3);
        address payable[] memory addresses = new address payable[](3);
        
        names[0] = "Red Cross";
        names[1] = "UNICEF";
        names[2] = "Doctors Without Borders";
        
        addresses[0] = payable(makeAddr("redCross"));
        addresses[1] = payable(makeAddr("unicef"));
        addresses[2] = payable(makeAddr("doctors"));
        
        // Add charities in batch
        vm.prank(owner);
        router.addCharitiesBatch(names, addresses);
        
        // Verify all charities were added
        assertEq(router.getCharityCount(), 3);
        
        // Verify each charity individually
        for (uint256 i = 0; i < 3; i++) {
            CharityRouter.Charity memory charity = router.getCharityByAddress(addresses[i]);
            assertEq(charity.name, names[i]);
            assertEq(charity.walletAddress, addresses[i]);
            assertTrue(charity.isActive);
            assertEq(charity.totalEthReceived, 0);
            assertEq(charity.donationCount, 0);
            assertGt(charity.registeredAt, 0);
        }
        
        // Verify name mappings work
        for (uint256 i = 0; i < 3; i++) {
            assertEq(router.charitiesByName(names[i]), addresses[i]);
            CharityRouter.Charity memory charityByName = router.getCharityByName(names[i]);
            assertEq(charityByName.walletAddress, addresses[i]);
        }
        
        // Verify address array is populated
        for (uint256 i = 0; i < 3; i++) {
            assertEq(router.charityAddresses(i), addresses[i]);
        }
    }

    function testStep5_ArrayLengthMismatch() public {
        // Create mismatched arrays
        string[] memory names = new string[](2);
        address payable[] memory addresses = new address payable[](3);
        
        names[0] = "Red Cross";
        names[1] = "UNICEF";
        
        addresses[0] = payable(makeAddr("redCross"));
        addresses[1] = payable(makeAddr("unicef"));
        addresses[2] = payable(makeAddr("doctors"));
        
        // Should revert with array length mismatch
        vm.prank(owner);
        vm.expectRevert(CharityRouter.ArrayLengthMismatch.selector);
        router.addCharitiesBatch(names, addresses);
    }

    function testStep5_EmptyArrays() public {
        // Create empty arrays
        string[] memory names = new string[](0);
        address payable[] memory addresses = new address payable[](0);
        
        // Should revert with empty array
        vm.prank(owner);
        vm.expectRevert(CharityRouter.EmptyCharityName.selector); // Reusing existing error
        router.addCharitiesBatch(names, addresses);
    }

    function testStep5_InvalidAddressInBatch() public {
        // Create batch with one invalid address
        string[] memory names = new string[](2);
        address payable[] memory addresses = new address payable[](2);
        
        names[0] = "Red Cross";
        names[1] = "UNICEF";
        
        addresses[0] = payable(makeAddr("redCross"));
        addresses[1] = payable(address(0)); // Invalid address
        
        // Should revert when it hits the invalid address
        vm.prank(owner);
        vm.expectRevert(CharityRouter.InvalidCharityAddress.selector);
        router.addCharitiesBatch(names, addresses);
        
        // Verify no charities were added (atomic operation)
        assertEq(router.getCharityCount(), 0);
    }

    function testStep5_EmptyNameInBatch() public {
        // Create batch with one empty name
        string[] memory names = new string[](2);
        address payable[] memory addresses = new address payable[](2);
        
        names[0] = "Red Cross";
        names[1] = ""; // Empty name
        
        addresses[0] = payable(makeAddr("redCross"));
        addresses[1] = payable(makeAddr("unicef"));
        
        // Should revert when it hits the empty name
        vm.prank(owner);
        vm.expectRevert(CharityRouter.EmptyCharityName.selector);
        router.addCharitiesBatch(names, addresses);
        
        // Verify no charities were added (atomic operation)
        assertEq(router.getCharityCount(), 0);
    }

    function testStep5_DuplicateAddressInBatch() public {
        // Create batch with duplicate addresses
        string[] memory names = new string[](2);
        address payable[] memory addresses = new address payable[](2);
        
        names[0] = "Red Cross";
        names[1] = "Different Name";
        
        address sameAddr = makeAddr("same");
        addresses[0] = payable(sameAddr);
        addresses[1] = payable(sameAddr); // Duplicate address
        
        // Should revert when it detects duplicate
        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityAlreadyExists.selector);
        router.addCharitiesBatch(names, addresses);
        
        // Verify no charities were added
        assertEq(router.getCharityCount(), 0);
    }

    function testStep5_DuplicateNameInBatch() public {
        // Create batch with duplicate names
        string[] memory names = new string[](2);
        address payable[] memory addresses = new address payable[](2);
        
        names[0] = "Red Cross";
        names[1] = "Red Cross"; // Duplicate name
        
        addresses[0] = payable(makeAddr("redCross"));
        addresses[1] = payable(makeAddr("unicef"));
        
        // Should revert when it detects duplicate name
        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityAlreadyExists.selector);
        router.addCharitiesBatch(names, addresses);
        
        // Verify no charities were added
        assertEq(router.getCharityCount(), 0);
    }

    function testStep5_DuplicateWithExistingCharity() public {
        // Add a charity first
        string memory existingName = "Red Cross";
        address payable existingAddress = payable(makeAddr("redCross"));
        
        vm.prank(owner);
        router.addCharity(existingName, existingAddress);
        
        // Try to add batch that conflicts with existing charity
        string[] memory names = new string[](2);
        address payable[] memory addresses = new address payable[](2);
        
        names[0] = "UNICEF";
        names[1] = existingName; // Conflicts with existing
        
        addresses[0] = payable(makeAddr("unicef"));
        addresses[1] = payable(makeAddr("doctors"));
        
        // Should revert when it detects existing name
        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityAlreadyExists.selector);
        router.addCharitiesBatch(names, addresses);
        
        // Verify only original charity exists
        assertEq(router.getCharityCount(), 1);
    }

    function testStep5_OnlyOwnerCanBatchAdd() public {
        // Prepare batch data
        string[] memory names = new string[](1);
        address payable[] memory addresses = new address payable[](1);
        
        names[0] = "Test Charity";
        addresses[0] = payable(makeAddr("testCharity"));
        
        // Try to add as non-owner
        vm.prank(notOwner);
        vm.expectRevert(); // Should revert with Ownable error
        router.addCharitiesBatch(names, addresses);
        
        // Verify no charities were added
        assertEq(router.getCharityCount(), 0);
    }

    function testStep5_EventsEmittedForEachCharity() public {
        // Prepare batch data
        string[] memory names = new string[](2);
        address payable[] memory addresses = new address payable[](2);
        
        names[0] = "Red Cross";
        names[1] = "UNICEF";
        
        addresses[0] = payable(makeAddr("redCross"));
        addresses[1] = payable(makeAddr("unicef"));
        
        // Expect events for each charity
        vm.expectEmit(true, false, false, true);
        emit CharityAdded(addresses[0], names[0], block.timestamp);
        
        vm.expectEmit(true, false, false, true);
        emit CharityAdded(addresses[1], names[1], block.timestamp);
        
        vm.prank(owner);
        router.addCharitiesBatch(names, addresses);
    }

    function testStep5_LargeBatchAddition() public {
        // Test with larger batch (10 charities)
        uint256 batchSize = 10;
        string[] memory names = new string[](batchSize);
        address payable[] memory addresses = new address payable[](batchSize);
        
        for (uint256 i = 0; i < batchSize; i++) {
            names[i] = string(abi.encodePacked("Charity ", vm.toString(i)));
            addresses[i] = payable(makeAddr(string(abi.encodePacked("charity", vm.toString(i)))));
        }
        
        // Add large batch
        vm.prank(owner);
        router.addCharitiesBatch(names, addresses);
        
        // Verify all were added
        assertEq(router.getCharityCount(), batchSize);
        
        // Spot check a few charities
        CharityRouter.Charity memory firstCharity = router.getCharityByAddress(addresses[0]);
        assertEq(firstCharity.name, names[0]);
        
        CharityRouter.Charity memory lastCharity = router.getCharityByAddress(addresses[batchSize - 1]);
        assertEq(lastCharity.name, names[batchSize - 1]);
    }

    function testStep5_SingleCharityBatch() public {
        // Test batch with just one charity (edge case)
        string[] memory names = new string[](1);
        address payable[] memory addresses = new address payable[](1);
        
        names[0] = "Solo Charity";
        addresses[0] = payable(makeAddr("soloCharity"));
        
        vm.prank(owner);
        router.addCharitiesBatch(names, addresses);
        
        // Verify charity was added
        assertEq(router.getCharityCount(), 1);
        
        CharityRouter.Charity memory charity = router.getCharityByAddress(addresses[0]);
        assertEq(charity.name, names[0]);
        assertEq(charity.walletAddress, addresses[0]);
        assertTrue(charity.isActive);
    }

    function testStep5_MixedValidAndInvalidData() public {
        // Test that if ANY charity in batch is invalid, NONE are added
        string[] memory names = new string[](3);
        address payable[] memory addresses = new address payable[](3);
        
        names[0] = "Valid Charity 1";
        names[1] = ""; // Invalid: empty name
        names[2] = "Valid Charity 2";
        
        addresses[0] = payable(makeAddr("valid1"));
        addresses[1] = payable(makeAddr("valid2"));
        addresses[2] = payable(makeAddr("valid3"));
        
        // Should revert on second charity
        vm.prank(owner);
        vm.expectRevert(CharityRouter.EmptyCharityName.selector);
        router.addCharitiesBatch(names, addresses);
        
        // Verify NO charities were added (atomic transaction)
        assertEq(router.getCharityCount(), 0);
        
        // Verify first charity (which was valid) was not added
        CharityRouter.Charity memory firstCharity = router.getCharityByAddress(addresses[0]);
        assertEq(firstCharity.walletAddress, address(0));
    }

    function testStep5_GasUsageReasonable() public {
        // Test gas usage for batch vs individual adds
        uint256 batchSize = 5;
        string[] memory names = new string[](batchSize);
        address payable[] memory addresses = new address payable[](batchSize);
        
        for (uint256 i = 0; i < batchSize; i++) {
            names[i] = string(abi.encodePacked("Charity ", vm.toString(i)));
            addresses[i] = payable(makeAddr(string(abi.encodePacked("charity", vm.toString(i)))));
        }
        
        // Measure gas for batch operation
        uint256 gasBefore = gasleft();
        vm.prank(owner);
        router.addCharitiesBatch(names, addresses);
        uint256 batchGasUsed = gasBefore - gasleft();
        
        // Reset for individual adds comparison
        vm.prank(owner);
        router = new CharityRouter(owner);
        
        // Measure gas for individual operations
        gasBefore = gasleft();
        vm.startPrank(owner);
        for (uint256 i = 0; i < batchSize; i++) {
            router.addCharity(names[i], addresses[i]);
        }
        vm.stopPrank();
        uint256 individualGasUsed = gasBefore - gasleft();
        
        // Batch should be more gas efficient (or at least not significantly worse)
        // Allow some tolerance since batch has additional validation overhead
        assertTrue(batchGasUsed <= individualGasUsed * 12 / 10); // Max 20% overhead
        
        console.log("Batch gas used:", batchGasUsed);
        console.log("Individual gas used:", individualGasUsed);
        console.log("Gas savings:", individualGasUsed > batchGasUsed ? individualGasUsed - batchGasUsed : 0);
    }
}