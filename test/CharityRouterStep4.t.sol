// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/CharityRouter.sol";

contract CharityRouterStep4Test is Test {
    CharityRouter public router;
    address public owner;
    address public notOwner;

    // Event declarations for testing
    event CharityUpdated(address indexed charityAddress, string oldName, string newName);
    event CharityRemoved(address indexed charityAddress, string name);
    event CharityStatusChanged(address indexed charityAddress, bool isActive);

    function setUp() public {
        // Set up test addresses
        owner = makeAddr("owner");
        notOwner = makeAddr("notOwner");

        // Deploy contract with owner
        vm.prank(owner);
        router = new CharityRouter(owner);
    }

    // ===== STEP 4 TESTS: Charity Management Functions =====

    function testStep4_SuccessfulCharityUpdate() public {
        // Add a charity first
        string memory oldName = "Red Cross";
        string memory newName = "American Red Cross";
        address payable charityAddress = payable(makeAddr("redCross"));

        vm.prank(owner);
        router.addCharity(oldName, charityAddress);

        // Update the charity name
        vm.expectEmit(true, false, false, true);
        emit CharityUpdated(charityAddress, oldName, newName);

        vm.prank(owner);
        router.updateCharity(charityAddress, newName);

        // Verify the name was updated
        CharityRouter.Charity memory updatedCharity = router.getCharityByAddress(charityAddress);
        assertEq(updatedCharity.name, newName);

        // Verify old name mapping is removed and new one is added
        assertEq(router.charitiesByName(oldName), address(0));
        assertEq(router.charitiesByName(newName), charityAddress);

        // Verify we can retrieve by new name
        CharityRouter.Charity memory charityByNewName = router.getCharityByName(newName);
        assertEq(charityByNewName.name, newName);
        assertEq(charityByNewName.walletAddress, charityAddress);
    }

    function testStep4_UpdateNonExistentCharity() public {
        address nonExistentAddress = makeAddr("nonExistent");

        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.updateCharity(nonExistentAddress, "New Name");
    }

    function testStep4_UpdateToEmptyName() public {
        // Add a charity first
        string memory charityName = "Test Charity";
        address payable charityAddress = payable(makeAddr("testCharity"));

        vm.prank(owner);
        router.addCharity(charityName, charityAddress);

        // Try to update to empty name
        vm.prank(owner);
        vm.expectRevert(CharityRouter.EmptyCharityName.selector);
        router.updateCharity(charityAddress, "");
    }

    function testStep4_UpdateToExistingName() public {
        // Add two charities
        string memory firstName = "Red Cross";
        string memory secondName = "UNICEF";
        address payable firstAddress = payable(makeAddr("redCross"));
        address payable secondAddress = payable(makeAddr("unicef"));

        vm.startPrank(owner);
        router.addCharity(firstName, firstAddress);
        router.addCharity(secondName, secondAddress);

        // Try to update second charity to first charity's name
        vm.expectRevert(CharityRouter.NameAlreadyTaken.selector);
        router.updateCharity(secondAddress, firstName);
        vm.stopPrank();
    }

    function testStep4_UpdateToSameName() public {
        // Add a charity
        string memory charityName = "Red Cross";
        address payable charityAddress = payable(makeAddr("redCross"));

        vm.startPrank(owner);
        router.addCharity(charityName, charityAddress);

        // Update to the same name (should be allowed)
        router.updateCharity(charityAddress, charityName);
        vm.stopPrank();

        // Verify name is still the same
        CharityRouter.Charity memory charity = router.getCharityByAddress(charityAddress);
        assertEq(charity.name, charityName);
    }

    function testStep4_OnlyOwnerCanUpdate() public {
        // Add a charity
        string memory charityName = "Test Charity";
        address payable charityAddress = payable(makeAddr("testCharity"));

        vm.prank(owner);
        router.addCharity(charityName, charityAddress);

        // Try to update as non-owner
        vm.prank(notOwner);
        vm.expectRevert(); // Should revert with Ownable error
        router.updateCharity(charityAddress, "New Name");
    }

    function testStep4_SuccessfulCharityRemoval() public {
        // Add a charity first
        string memory charityName = "Red Cross";
        address payable charityAddress = payable(makeAddr("redCross"));

        vm.prank(owner);
        router.addCharity(charityName, charityAddress);

        // Remove the charity
        vm.expectEmit(true, false, false, true);
        emit CharityRemoved(charityAddress, charityName);

        vm.prank(owner);
        router.removeCharity(charityAddress);

        // Verify charity is marked as removed (wallet address set to zero)
        CharityRouter.Charity memory removedCharity = router.getCharityByAddress(charityAddress);
        assertEq(removedCharity.walletAddress, address(0));
        assertEq(removedCharity.isActive, false);

        // Verify name mapping is removed
        assertEq(router.charitiesByName(charityName), address(0));

        // Verify charity count remains the same (we don't remove from array)
        assertEq(router.getCharityCount(), 1);
    }

    function testStep4_RemoveNonExistentCharity() public {
        address nonExistentAddress = makeAddr("nonExistent");

        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.removeCharity(nonExistentAddress);
    }

    function testStep4_OnlyOwnerCanRemove() public {
        // Add a charity
        string memory charityName = "Test Charity";
        address payable charityAddress = payable(makeAddr("testCharity"));

        vm.prank(owner);
        router.addCharity(charityName, charityAddress);

        // Try to remove as non-owner
        vm.prank(notOwner);
        vm.expectRevert(); // Should revert with Ownable error
        router.removeCharity(charityAddress);
    }

    function testStep4_SuccessfulStatusChange() public {
        // Add a charity first
        string memory charityName = "Red Cross";
        address payable charityAddress = payable(makeAddr("redCross"));

        vm.prank(owner);
        router.addCharity(charityName, charityAddress);

        // Verify charity starts as active
        CharityRouter.Charity memory charity = router.getCharityByAddress(charityAddress);
        assertTrue(charity.isActive);

        // Deactivate the charity
        vm.expectEmit(true, false, false, true);
        emit CharityStatusChanged(charityAddress, false);

        vm.prank(owner);
        router.setCharityStatus(charityAddress, false);

        // Verify status changed
        charity = router.getCharityByAddress(charityAddress);
        assertFalse(charity.isActive);

        // Reactivate the charity
        vm.expectEmit(true, false, false, true);
        emit CharityStatusChanged(charityAddress, true);

        vm.prank(owner);
        router.setCharityStatus(charityAddress, true);

        // Verify status changed back
        charity = router.getCharityByAddress(charityAddress);
        assertTrue(charity.isActive);
    }

    function testStep4_SetStatusNonExistentCharity() public {
        address nonExistentAddress = makeAddr("nonExistent");

        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.setCharityStatus(nonExistentAddress, false);
    }

    function testStep4_OnlyOwnerCanSetStatus() public {
        // Add a charity
        string memory charityName = "Test Charity";
        address payable charityAddress = payable(makeAddr("testCharity"));

        vm.prank(owner);
        router.addCharity(charityName, charityAddress);

        // Try to change status as non-owner
        vm.prank(notOwner);
        vm.expectRevert(); // Should revert with Ownable error
        router.setCharityStatus(charityAddress, false);
    }

    function testStep4_OperationsOnRemovedCharity() public {
        // Add a charity
        string memory charityName = "Test Charity";
        address payable charityAddress = payable(makeAddr("testCharity"));

        vm.startPrank(owner);
        router.addCharity(charityName, charityAddress);

        // Remove the charity
        router.removeCharity(charityAddress);

        // Try to update removed charity
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.updateCharity(charityAddress, "New Name");

        // Try to change status of removed charity
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.setCharityStatus(charityAddress, true);

        // Try to remove already removed charity
        vm.expectRevert(CharityRouter.CharityNotFound.selector);
        router.removeCharity(charityAddress);

        vm.stopPrank();
    }

    function testStep4_EventEmissionCorrectness() public {
        // Test that all events emit correct data
        string memory charityName = "Test Charity";
        address payable charityAddress = payable(makeAddr("testCharity"));

        vm.startPrank(owner);
        router.addCharity(charityName, charityAddress);

        // Test update event
        string memory newName = "Updated Charity";
        vm.expectEmit(true, false, false, true);
        emit CharityUpdated(charityAddress, charityName, newName);
        router.updateCharity(charityAddress, newName);

        // Test status change event
        vm.expectEmit(true, false, false, true);
        emit CharityStatusChanged(charityAddress, false);
        router.setCharityStatus(charityAddress, false);

        // Test removal event
        vm.expectEmit(true, false, false, true);
        emit CharityRemoved(charityAddress, newName);
        router.removeCharity(charityAddress);

        vm.stopPrank();
    }
}
