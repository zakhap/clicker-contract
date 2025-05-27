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

    // ===== DONATION TRACKING =====

    /// @notice Total number of donations processed
    uint256 public totalDonations;

    /// @notice Next donation ID to be assigned
    uint256 public nextDonationId;

    /// @notice Total amount of ETH routed through the contract
    uint256 public totalEthRouted;

    // ===== EVENTS =====

    /**
     * @notice Emitted when a new charity is added to the registry
     * @param charityAddress Address of the charity wallet
     * @param name Name of the charity
     * @param timestamp When the charity was registered
     */
    event CharityAdded(address indexed charityAddress, string name, uint256 timestamp);

    /**
     * @notice Emitted when a charity's information is updated
     * @param charityAddress Address of the charity
     * @param oldName Previous name of the charity
     * @param newName New name of the charity
     */
    event CharityUpdated(address indexed charityAddress, string oldName, string newName);

    /**
     * @notice Emitted when a charity is removed from the registry
     * @param charityAddress Address of the charity that was removed
     * @param name Name of the charity that was removed
     */
    event CharityRemoved(address indexed charityAddress, string name);

    /**
     * @notice Emitted when a charity's active status changes
     * @param charityAddress Address of the charity
     * @param isActive New active status
     */
    event CharityStatusChanged(address indexed charityAddress, bool isActive);

    /**
     * @notice Emitted when a donation is routed to a charity
     * @param donationId Unique identifier for this donation
     * @param donor Address of the donor
     * @param charity Address of the charity that received the donation
     * @param amount Amount of ETH donated
     * @param charityName Name of the charity
     */
    event DonationRouted(
        uint256 indexed donationId, address indexed donor, address indexed charity, uint256 amount, string charityName
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

    /// @notice Thrown when trying to donate to an inactive charity
    error InactiveCharity();

    /// @notice Thrown when trying to donate zero ETH
    error EmptyDonation();

    /// @notice Thrown when ETH transfer to charity fails
    error TransferFailed();

    // ===== CONSTRUCTOR =====

    /**
     * @notice Contract constructor
     * @param _initialOwner Address that will own the contract
     */
    constructor(address _initialOwner) Ownable(_initialOwner) {
        // Constructor sets initial owner via Ownable
        // Donation counters start at 0 by default
        nextDonationId = 1; // Start donation IDs at 1
    }

    // ===== DONATION FUNCTIONS =====

    /**
     * @notice Donate ETH to a charity by address
     * @param _charityAddress Address of the charity to donate to
     * @dev ETH is immediately transferred to the charity wallet
     */
    function donate(address _charityAddress) external payable nonReentrant {
        // Validate donation amount
        if (msg.value == 0) {
            revert EmptyDonation();
        }

        // Validate charity
        _validateCharityForDonation(_charityAddress);

        // Process the donation
        _processDonation(_charityAddress, msg.value);
    }

    /**
     * @notice Donate ETH to a charity by name
     * @param _charityName Name of the charity to donate to
     * @dev ETH is immediately transferred to the charity wallet
     */
    function donateByName(string memory _charityName) external payable nonReentrant {
        // Validate donation amount
        if (msg.value == 0) {
            revert EmptyDonation();
        }

        // Resolve charity name to address
        address charityAddress = charitiesByName[_charityName];

        // Validate charity exists and is active
        _validateCharityForDonation(charityAddress);

        // Process the donation
        _processDonation(charityAddress, msg.value);
    }

    // ===== INTERNAL HELPER FUNCTIONS =====

    /**
     * @notice Validate that a charity can receive donations
     * @param _charityAddress Address of the charity to validate
     */
    function _validateCharityForDonation(address _charityAddress) internal view {
        // Check if charity exists
        if (charitiesByAddress[_charityAddress].walletAddress == address(0)) {
            revert CharityNotFound();
        }

        // Check if charity is active
        if (!charitiesByAddress[_charityAddress].isActive) {
            revert InactiveCharity();
        }
    }

    /**
     * @notice Process a donation to a charity
     * @param _charityAddress Address of the charity
     * @param _amount Amount of ETH to donate
     */
    function _processDonation(address _charityAddress, uint256 _amount) internal {
        // Get charity info
        Charity storage charity = charitiesByAddress[_charityAddress];

        // Update donation statistics
        uint256 donationId = nextDonationId++;
        totalDonations++;
        totalEthRouted += _amount;
        charity.totalEthReceived += _amount;
        charity.donationCount++;

        // Transfer ETH directly to charity
        (bool success,) = charity.walletAddress.call{value: _amount}("");
        if (!success) {
            revert TransferFailed();
        }

        // Emit donation event
        emit DonationRouted(donationId, msg.sender, _charityAddress, _amount, charity.name);
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
    function addCharitiesBatch(string[] memory _names, address payable[] memory _walletAddresses) external onlyOwner {
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

    /**
     * @notice Get donation statistics
     * @return totalDonations_ Total number of donations processed
     * @return totalEthRouted_ Total amount of ETH routed
     * @return nextDonationId_ Next donation ID to be assigned
     */
    function getDonationStats()
        external
        view
        returns (uint256 totalDonations_, uint256 totalEthRouted_, uint256 nextDonationId_)
    {
        return (totalDonations, totalEthRouted, nextDonationId);
    }

    /**
     * @notice Get all registered charity addresses
     * @return Array of charity addresses
     * @dev Includes removed charities (with zero addresses) to preserve indices
     */
    function getAllCharities() external view returns (address[] memory) {
        return charityAddresses;
    }

    /**
     * @notice Get detailed statistics for a specific charity
     * @param _charityAddress Address of the charity
     * @return name_ Name of the charity
     * @return isActive_ Whether the charity is currently active
     * @return totalEthReceived_ Total ETH received by this charity
     * @return donationCount_ Number of donations made to this charity
     * @return registeredAt_ Timestamp when charity was registered
     */
    function getCharityStats(address _charityAddress)
        external
        view
        returns (
            string memory name_,
            bool isActive_,
            uint256 totalEthReceived_,
            uint256 donationCount_,
            uint256 registeredAt_
        )
    {
        Charity memory charity = charitiesByAddress[_charityAddress];
        return (charity.name, charity.isActive, charity.totalEthReceived, charity.donationCount, charity.registeredAt);
    }

    /**
     * @notice Get comprehensive global statistics
     * @return totalCharities_ Total number of registered charities
     * @return activeCharities_ Number of currently active charities
     * @return totalDonations_ Total number of donations processed
     * @return totalEthRouted_ Total amount of ETH routed through the contract
     * @return averageDonationSize_ Average donation size in wei
     */
    function getTotalStats()
        external
        view
        returns (
            uint256 totalCharities_,
            uint256 activeCharities_,
            uint256 totalDonations_,
            uint256 totalEthRouted_,
            uint256 averageDonationSize_
        )
    {
        uint256 activeCount = 0;

        // Count active charities
        for (uint256 i = 0; i < charityAddresses.length; i++) {
            if (
                charitiesByAddress[charityAddresses[i]].isActive
                    && charitiesByAddress[charityAddresses[i]].walletAddress != address(0)
            ) {
                activeCount++;
            }
        }

        // Calculate average donation size
        uint256 avgDonation = 0;
        if (totalDonations > 0) {
            avgDonation = totalEthRouted / totalDonations;
        }

        return (charityAddresses.length, activeCount, totalDonations, totalEthRouted, avgDonation);
    }

    /**
     * @notice Check if a charity address is valid and active
     * @param _charityAddress Address to check
     * @return True if charity exists and is active
     */
    function isValidCharity(address _charityAddress) external view returns (bool) {
        return charitiesByAddress[_charityAddress].walletAddress != address(0)
            && charitiesByAddress[_charityAddress].isActive;
    }

    /**
     * @notice Check if a charity name is valid and active
     * @param _charityName Name to check
     * @return True if charity name exists and is active
     */
    function isValidCharityName(string memory _charityName) external view returns (bool) {
        address charityAddress = charitiesByName[_charityName];
        return charitiesByAddress[charityAddress].walletAddress != address(0)
            && charitiesByAddress[charityAddress].isActive;
    }
}
