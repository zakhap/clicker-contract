// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/CharityRouter.sol";

contract CharityRouterTest is Test {
    CharityRouter public router;
    address public owner;
    address public newOwner;
    address public notOwner;

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
}