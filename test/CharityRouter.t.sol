// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/CharityRouter.sol";

contract CharityRouterTest is Test {
    CharityRouter public router;
    address public owner;
    address public newOwner;
    address public notOwner;

    // Add event declaration for testing
    event CharityAdded(address indexed charityAddress, string name, uint256 timestamp);

    function setUp() public {
        // Set up test addresses
        owner = makeAddr("owner");
        newOwner = makeAddr("newOwner");
        notOwner = makeAddr("notOwner");
        
        // Deploy contract with owner
        vm.prank(owner);
        router = new CharityRouter(owner);
    }

    // ===== STEP 1 TESTS: Basic Contract Structure & Ownership =====

    function testStep1_ContractDeployment() public view {
        // Test contract deploys successfully
        assertTrue(address(router) != address(0));
        assertEq(router.VERSION(), "1.0.0");
        assertEq(router.getVersion(), "1.0.0");
    }

    function testStep1_OwnerSetCorrectly() public view {
        // Test owner is set correctly during deployment
        assertEq(router.owner(), owner);
    }

    function testStep1_OwnershipTransfer() public {
        // Test ownership can be transferred by current owner
        vm.prank(owner);
        router.transferOwnership(newOwner);
        
        // Ownership should be pending until accepted
        assertEq(router.owner(), owner);
        assertEq(router.pendingOwner(), newOwner);
        
        // New owner accepts ownership
        vm.prank(newOwner);
        router.acceptOwnership();
        
        assertEq(router.owner(), newOwner);
        assertEq(router.pendingOwner(), address(0));
    }

    function testStep1_OnlyOwnerCanTransferOwnership() public {
        // Test that only owner can transfer ownership
        vm.prank(notOwner);
        vm.expectRevert();
        router.transferOwnership(newOwner);
        
        // Owner should remain unchanged
        assertEq(router.owner(), owner);
    }

    function testStep1_TransferToZeroAddressAllowed() public {
        // Test that transferring to zero address is allowed (for renouncing)
        vm.prank(owner);
        router.transferOwnership(address(0));
        
        // Should have zero address as pending owner
        assertEq(router.pendingOwner(), address(0));
        assertEq(router.owner(), owner); // Owner unchanged until accepted
    }

    function testStep1_OnlyPendingOwnerCanAccept() public {
        // Set up pending ownership transfer
        vm.prank(owner);
        router.transferOwnership(newOwner);
        
        // Test that only pending owner can accept
        vm.prank(notOwner);
        vm.expectRevert();
        router.acceptOwnership();
        
        // Original owner should still be owner
        assertEq(router.owner(), owner);
    }

    function testStep1_RenounceOwnership() public {
        // Test owner can renounce ownership directly
        vm.prank(owner);
        router.renounceOwnership();
        
        assertEq(router.owner(), address(0));
        assertEq(router.pendingOwner(), address(0));
    }

    // ===== STEP 2 TESTS: Charity Data Structures & Storage =====

    function testStep2_CharityStructCreation() public {
        // Test that we can create and access charity struct
        // Since no charities are registered, all values should be default
        address nonExistentAddr = makeAddr("nonExistent");
        CharityRouter.Charity memory emptyCharity = router.getCharityByAddress(nonExistentAddr);
        
        assertEq(emptyCharity.name, "");
        assertEq(emptyCharity.walletAddress, address(0));
        assertEq(emptyCharity.isActive, false);
        assertEq(emptyCharity.totalEthReceived, 0);
        assertEq(emptyCharity.donationCount, 0);
        assertEq(emptyCharity.registeredAt, 0);
    }

    function testStep2_GetCharityByAddressEmpty() public {
        // Test getter returns empty struct for non-existent charity
        address nonExistentAddress = makeAddr("nonExistent");
        CharityRouter.Charity memory charity = router.getCharityByAddress(nonExistentAddress);
        
        assertEq(charity.name, "");
        assertEq(charity.walletAddress, address(0));
        assertEq(charity.isActive, false);
        assertEq(charity.totalEthReceived, 0);
        assertEq(charity.donationCount, 0);
        assertEq(charity.registeredAt, 0);
    }

    function testStep2_GetCharityByNameEmpty() public view {
        // Test getter returns empty struct for non-existent charity name
        CharityRouter.Charity memory charity = router.getCharityByName("NonExistentCharity");
        
        assertEq(charity.name, "");
        assertEq(charity.walletAddress, address(0));
        assertEq(charity.isActive, false);
        assertEq(charity.totalEthReceived, 0);
        assertEq(charity.donationCount, 0);
        assertEq(charity.registeredAt, 0);
    }

    function testStep2_GetCharityCount() public view {
        // Test charity count is initially zero
        assertEq(router.getCharityCount(), 0);
    }

    function testStep2_StorageMappingsExist() public {
        // Test that storage mappings are accessible (they return default values)
        address testAddress = makeAddr("test");
        
        // Test charitiesByAddress mapping
        (
            string memory name,
            address payable walletAddress,
            bool isActive,
            uint256 totalEthReceived,
            uint256 donationCount,
            uint256 registeredAt
        ) = router.charitiesByAddress(testAddress);
        
        assertEq(name, "");
        assertEq(walletAddress, address(0));
        assertEq(isActive, false);
        assertEq(totalEthReceived, 0);
        assertEq(donationCount, 0);
        assertEq(registeredAt, 0);
        
        // Test charitiesByName mapping
        address mappedAddress = router.charitiesByName("TestCharity");
        assertEq(mappedAddress, address(0));
    }

    function testStep2_CharityAddressesArray() public {
        // Test charityAddresses array is initially empty
        assertEq(router.getCharityCount(), 0);
        
        // Test we can't access non-existent array elements
        vm.expectRevert();
        router.charityAddresses(0);
    }

    // ===== STEP 3 TESTS: Single Charity Registration =====

    function testStep3_SuccessfulCharityAddition() public {
        // Set up charity data
        string memory charityName = "Red Cross";
        address payable charityAddress = payable(makeAddr("redCross"));
        
        // Add charity as owner
        vm.prank(owner);
        router.addCharity(charityName, charityAddress);
        
        // Verify charity count increased
        assertEq(router.getCharityCount(), 1);
        
        // Verify charity is stored correctly by address
        CharityRouter.Charity memory charityByAddr = router.getCharityByAddress(charityAddress);
        assertEq(charityByAddr.name, charityName);
        assertEq(charityByAddr.walletAddress, charityAddress);
        assertTrue(charityByAddr.isActive);
        assertEq(charityByAddr.totalEthReceived, 0);
        assertEq(charityByAddr.donationCount, 0);
        assertGt(charityByAddr.registeredAt, 0); // Should be current timestamp
        
        // Verify charity is stored correctly by name
        CharityRouter.Charity memory charityByName = router.getCharityByName(charityName);
        assertEq(charityByName.name, charityName);
        assertEq(charityByName.walletAddress, charityAddress);
        assertTrue(charityByName.isActive);
        
        // Verify address array is updated
        assertEq(router.charityAddresses(0), charityAddress);
    }

    function testStep3_CharityAddedEventEmission() public {
        string memory charityName = "UNICEF";
        address payable charityAddress = payable(makeAddr("unicef"));
        
        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit CharityAdded(charityAddress, charityName, block.timestamp);
        
        vm.prank(owner);
        router.addCharity(charityName, charityAddress);
    }

    function testStep3_DuplicateAddressPrevention() public {
        string memory firstName = "Red Cross";
        string memory secondName = "Different Name";
        address payable sameAddress = payable(makeAddr("sameAddr"));
        
        // Add first charity
        vm.prank(owner);
        router.addCharity(firstName, sameAddress);
        
        // Try to add second charity with same address
        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityAlreadyExists.selector);
        router.addCharity(secondName, sameAddress);
    }

    function testStep3_DuplicateNamePrevention() public {
        string memory sameName = "Red Cross";
        address payable firstAddress = payable(makeAddr("firstAddr"));
        address payable secondAddress = payable(makeAddr("secondAddr"));
        
        // Add first charity
        vm.prank(owner);
        router.addCharity(sameName, firstAddress);
        
        // Try to add second charity with same name
        vm.prank(owner);
        vm.expectRevert(CharityRouter.CharityAlreadyExists.selector);
        router.addCharity(sameName, secondAddress);
    }

    function testStep3_OnlyOwnerCanAdd() public {
        string memory charityName = "Test Charity";
        address payable charityAddress = payable(makeAddr("testCharity"));
        
        // Try to add charity as non-owner
        vm.prank(notOwner);
        vm.expectRevert(); // Should revert with Ownable error
        router.addCharity(charityName, charityAddress);
        
        // Verify no charity was added
        assertEq(router.getCharityCount(), 0);
    }

    function testStep3_ZeroAddressRejection() public {
        string memory charityName = "Invalid Charity";
        
        vm.prank(owner);
        vm.expectRevert(CharityRouter.InvalidCharityAddress.selector);
        router.addCharity(charityName, payable(address(0)));
    }

    function testStep3_EmptyNameRejection() public {
        address payable charityAddress = payable(makeAddr("validAddress"));
        
        vm.prank(owner);
        vm.expectRevert(CharityRouter.EmptyCharityName.selector);
        router.addCharity("", charityAddress);
    }

    function testStep3_MappingConsistency() public {
        string memory charityName = "Doctors Without Borders";
        address payable charityAddress = payable(makeAddr("doctors"));
        
        vm.prank(owner);
        router.addCharity(charityName, charityAddress);
        
        // Test that both mappings point to the same data
        assertEq(router.charitiesByName(charityName), charityAddress);
        
        CharityRouter.Charity memory charityByAddr = router.getCharityByAddress(charityAddress);
        CharityRouter.Charity memory charityByName = router.getCharityByName(charityName);
        
        // Both should return identical data
        assertEq(charityByAddr.name, charityByName.name);
        assertEq(charityByAddr.walletAddress, charityByName.walletAddress);
        assertEq(charityByAddr.isActive, charityByName.isActive);
        assertEq(charityByAddr.totalEthReceived, charityByName.totalEthReceived);
        assertEq(charityByAddr.donationCount, charityByName.donationCount);
        assertEq(charityByAddr.registeredAt, charityByName.registeredAt);
    }
}