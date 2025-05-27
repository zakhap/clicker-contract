// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CharityRouter
 * @author Your Team
 * @notice A transparent router contract for charitable donations on Base chain
 * @dev Routes ETH donations directly to approved charities with transparent tracking
 */
contract CharityRouter is Ownable2Step, ReentrancyGuard {
    
    /// @notice Contract version
    string public constant VERSION = "1.0.0";
    
    /**
     * @notice Contract constructor
     * @param _initialOwner Address that will own the contract
     */
    constructor(address _initialOwner) Ownable(_initialOwner) {
        // Constructor sets initial owner via Ownable
    }
    
    /**
     * @notice Get the contract version
     * @return Version string
     */
    function getVersion() external pure returns (string memory) {
        return VERSION;
    }
}