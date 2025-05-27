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
    
    // ===== DATA STRUCTURES =====
    
    /**
     * @notice Charity information struct
     * @param name Human-readable name of the charity
     * @param walletAddress Address where donations will be sent
     * @param isActive Whether the charity can currently receive donations
     * @param totalEthReceived Total amount of ETH routed to this charity
     * @param donationCount Number of donations made to this charity
     * @param registeredAt Timestamp when charity was registered
     */
    struct Charity {
        string name;
        address payable walletAddress;
        bool isActive;
        uint256 totalEthReceived;
        uint256 donationCount;
        uint256 registeredAt;
    }
    
    // ===== STORAGE =====
    
    /// @notice Mapping from charity address to charity info
    mapping(address => Charity) public charitiesByAddress;
    
    /// @notice Mapping from charity name to charity address
    mapping(string => address) public charitiesByName;
    
    /// @notice Array of all registered charity addresses
    address[] public charityAddresses;
    
    // ===== CONSTRUCTOR =====
    
    /**
     * @notice Contract constructor
     * @param _initialOwner Address that will own the contract
     */
    constructor(address _initialOwner) Ownable(_initialOwner) {
        // Constructor sets initial owner via Ownable
    }
    
    // ===== VIEW FUNCTIONS =====
    
    /**
     * @notice Get the contract version
     * @return Version string
     */
    function getVersion() external pure returns (string memory) {
        return VERSION;
    }
    
    /**
     * @notice Get charity information by address
     * @param _charityAddress Address of the charity
     * @return Charity struct with all charity information
     */
    function getCharityByAddress(address _charityAddress) external view returns (Charity memory) {
        return charitiesByAddress[_charityAddress];
    }
    
    /**
     * @notice Get charity information by name
     * @param _name Name of the charity
     * @return Charity struct with all charity information
     */
    function getCharityByName(string memory _name) external view returns (Charity memory) {
        address charityAddress = charitiesByName[_name];
        return charitiesByAddress[charityAddress];
    }
    
    /**
     * @notice Get total number of registered charities
     * @return Number of charities in the registry
     */
    function getCharityCount() external view returns (uint256) {
        return charityAddresses.length;
    }
}