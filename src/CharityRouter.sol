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
    
    // ===== EVENTS =====
    
    /**
     * @notice Emitted when a new charity is added to the registry
     * @param charityAddress Address of the charity wallet
     * @param name Name of the charity
     * @param timestamp When the charity was registered
     */
    event CharityAdded(
        address indexed charityAddress,
        string name,
        uint256 timestamp
    );
    
    /**
     * @notice Emitted when a charity's information is updated
     * @param charityAddress Address of the charity
     * @param oldName Previous name of the charity
     * @param newName New name of the charity
     */
    event CharityUpdated(
        address indexed charityAddress,
        string oldName,
        string newName
    );
    
    /**
     * @notice Emitted when a charity is removed from the registry
     * @param charityAddress Address of the charity that was removed
     * @param name Name of the charity that was removed
     */
    event CharityRemoved(
        address indexed charityAddress,
        string name
    );
    
    /**
     * @notice Emitted when a charity's active status changes
     * @param charityAddress Address of the charity
     * @param isActive New active status
     */
    event CharityStatusChanged(
        address indexed charityAddress,
        bool isActive
    );
    
    // ===== ERRORS =====
    
    /// @notice Thrown when trying to register a charity with zero address
    error InvalidCharityAddress();
    
    /// @notice Thrown when trying to register a charity with empty name
    error EmptyCharityName();
    
    /// @notice Thrown when trying to register a charity that already exists
    error CharityAlreadyExists();
    
    /// @notice Thrown when trying to operate on a charity that doesn't exist
    error CharityNotFound();
    
    /// @notice Thrown when trying to update a charity name to one that already exists
    error NameAlreadyTaken();
    
    /// @notice Thrown when array lengths don't match in batch operations
    error ArrayLengthMismatch();
    
    // ===== CONSTRUCTOR =====
    
    /**
     * @notice Contract constructor
     * @param _initialOwner Address that will own the contract
     */
    constructor(address _initialOwner) Ownable(_initialOwner) {
        // Constructor sets initial owner via Ownable
    }
    
    // ===== ADMIN FUNCTIONS =====
    
    /**
     * @notice Add a new charity to the registry
     * @param _name Human-readable name of the charity
     * @param _walletAddress Address where donations will be sent
     * @dev Only contract owner can call this function
     */
    function addCharity(string memory _name, address payable _walletAddress) external onlyOwner {
        // Validate inputs
        if (_walletAddress == address(0)) {
            revert InvalidCharityAddress();
        }
        
        if (bytes(_name).length == 0) {
            revert EmptyCharityName();
        }
        
        // Check for duplicates
        if (charitiesByAddress[_walletAddress].walletAddress != address(0)) {
            revert CharityAlreadyExists();
        }
        
        if (charitiesByName[_name] != address(0)) {
            revert CharityAlreadyExists();
        }
        
        // Create charity struct
        Charity memory newCharity = Charity({
            name: _name,
            walletAddress: _walletAddress,
            isActive: true, // New charities are active by default
            totalEthReceived: 0,
            donationCount: 0,
            registeredAt: block.timestamp
        });
        
        // Store in mappings
        charitiesByAddress[_walletAddress] = newCharity;
        charitiesByName[_name] = _walletAddress;
        charityAddresses.push(_walletAddress);
        
        // Emit event
        emit CharityAdded(_walletAddress, _name, block.timestamp);
    }
    
    /**
     * @notice Add multiple charities to the registry in a single transaction
     * @param _names Array of charity names
     * @param _walletAddresses Array of charity wallet addresses
     * @dev Only contract owner can call this function. Arrays must be same length.
     */
    function addCharitiesBatch(
        string[] memory _names, 
        address payable[] memory _walletAddresses
    ) external onlyOwner {
        // Validate array lengths match
        if (_names.length != _walletAddresses.length) {
            revert ArrayLengthMismatch();
        }
        
        // Validate arrays are not empty  
        if (_names.length == 0) {
            revert EmptyCharityName(); // Reuse existing error for empty input
        }
        
        // Process each charity
        for (uint256 i = 0; i < _names.length; i++) {
            // Validate inputs (same validation as single add)
            if (_walletAddresses[i] == address(0)) {
                revert InvalidCharityAddress();
            }
            
            if (bytes(_names[i]).length == 0) {
                revert EmptyCharityName();
            }
            
            // Check for duplicates (existing and within current batch)
            if (charitiesByAddress[_walletAddresses[i]].walletAddress != address(0)) {
                revert CharityAlreadyExists();
            }
            
            if (charitiesByName[_names[i]] != address(0)) {
                revert CharityAlreadyExists();
            }
            
            // Check for duplicates within the current batch
            for (uint256 j = 0; j < i; j++) {
                if (_walletAddresses[i] == _walletAddresses[j]) {
                    revert CharityAlreadyExists();
                }
                if (keccak256(bytes(_names[i])) == keccak256(bytes(_names[j]))) {
                    revert CharityAlreadyExists();
                }
            }
            
            // Create charity struct
            Charity memory newCharity = Charity({
                name: _names[i],
                walletAddress: _walletAddresses[i],
                isActive: true,
                totalEthReceived: 0,
                donationCount: 0,
                registeredAt: block.timestamp
            });
            
            // Store in mappings
            charitiesByAddress[_walletAddresses[i]] = newCharity;
            charitiesByName[_names[i]] = _walletAddresses[i];
            charityAddresses.push(_walletAddresses[i]);
            
            // Emit event for each charity
            emit CharityAdded(_walletAddresses[i], _names[i], block.timestamp);
        }
    }
    
    /**
     * @notice Update a charity's name
     * @param _charityAddress Address of the charity to update
     * @param _newName New name for the charity
     * @dev Only contract owner can call this function
     */
    function updateCharity(address _charityAddress, string memory _newName) external onlyOwner {
        // Check if charity exists
        if (charitiesByAddress[_charityAddress].walletAddress == address(0)) {
            revert CharityNotFound();
        }
        
        // Validate new name
        if (bytes(_newName).length == 0) {
            revert EmptyCharityName();
        }
        
        // Check if new name is already taken (but not by the same charity)
        if (charitiesByName[_newName] != address(0) && charitiesByName[_newName] != _charityAddress) {
            revert NameAlreadyTaken();
        }
        
        // Get old name
        string memory oldName = charitiesByAddress[_charityAddress].name;
        
        // Update name in charity struct
        charitiesByAddress[_charityAddress].name = _newName;
        
        // Update name mapping - remove old name and add new name
        delete charitiesByName[oldName];
        charitiesByName[_newName] = _charityAddress;
        
        // Emit event
        emit CharityUpdated(_charityAddress, oldName, _newName);
    }
    
    /**
     * @notice Remove a charity from the registry
     * @param _charityAddress Address of the charity to remove
     * @dev Only contract owner can call this function. Sets address to zero.
     */
    function removeCharity(address _charityAddress) external onlyOwner {
        // Check if charity exists
        if (charitiesByAddress[_charityAddress].walletAddress == address(0)) {
            revert CharityNotFound();
        }
        
        // Get charity name for event
        string memory charityName = charitiesByAddress[_charityAddress].name;
        
        // Remove from name mapping
        delete charitiesByName[charityName];
        
        // Set wallet address to zero (marking as removed)
        charitiesByAddress[_charityAddress].walletAddress = payable(address(0));
        charitiesByAddress[_charityAddress].isActive = false;
        
        // Note: We don't remove from charityAddresses array to preserve donation history
        // and avoid gas-expensive array operations
        
        // Emit event
        emit CharityRemoved(_charityAddress, charityName);
    }
    
    /**
     * @notice Set a charity's active status
     * @param _charityAddress Address of the charity
     * @param _isActive New active status
     * @dev Only contract owner can call this function
     */
    function setCharityStatus(address _charityAddress, bool _isActive) external onlyOwner {
        // Check if charity exists
        if (charitiesByAddress[_charityAddress].walletAddress == address(0)) {
            revert CharityNotFound();
        }
        
        // Update status
        charitiesByAddress[_charityAddress].isActive = _isActive;
        
        // Emit event
        emit CharityStatusChanged(_charityAddress, _isActive);
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