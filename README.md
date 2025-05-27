# Charity Router Smart Contract

A transparent smart contract router for charitable donations on Base chain. The contract routes ETH donations directly to approved charities while providing transparent tracking and event emission.

## Features

- **Direct Routing**: No funds held by contract - donations route directly to charities
- **Transparent Tracking**: All donations tracked via events with unique IDs
- **Charity Management**: Admin-controlled charity registration and management
- **Dual Access**: Donate by charity address or name
- **Batch Operations**: Efficient batch charity registration
- **Gas Optimized**: Minimal storage, maximum efficiency

## Contract Architecture

- **Router Pattern**: Contract acts as a transparent router, not a treasury
- **Event-Driven**: Complete donation history available through events
- **Access Controlled**: Only admin can manage charity registrations
- **ETH Only**: V1 focuses on native ETH donations (ERC20 support planned for V2)

## Development Setup

### Prerequisites
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Installation

```bash
# Clone the repository
git clone <your-repo-url>
cd clicker-contract

# Install dependencies
forge install

# Copy environment file
cp .env.example .env
# Edit .env with your values

# Build contracts
forge build

# Run tests
forge test
```

### Environment Variables

Copy `.env.example` to `.env` and fill in:
- `PRIVATE_KEY`: Deployer private key (for testnet/mainnet)
- `BASE_RPC_URL`: Base mainnet RPC URL
- `BASE_SEPOLIA_RPC_URL`: Base Sepolia testnet RPC URL
- `BASESCAN_API_KEY`: For contract verification

## Usage

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract CharityRouterTest

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage

# Run all tests with verbose output
forge test -vv

# Format code
forge fmt
```

### Local Development & Deployment

#### Step 1: Start Local Blockchain
```bash
# Terminal 1 - Start local blockchain (anvil)
anvil

# This will start a local Ethereum node on http://localhost:8545
# It provides 10 test accounts with 10,000 ETH each
# The first account's private key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

#### Step 2: Deploy Contract Locally
```bash
# Terminal 2 - Deploy the CharityRouter contract
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  -v

# This will:
# 1. Deploy the CharityRouter contract
# 2. Add 3 sample charities (American Red Cross, Doctors Without Borders, Save the Children)
# 3. Transfer ownership to a specified address
# 4. Show detailed deployment information
```

#### Step 3: Test Deployment (Optional)
```bash
# Dry run (simulation only - no actual deployment)
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 -v

# Check deployment with specific verbosity
forge script script/Deploy.s.sol \
  --rpc-url http://localhost:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  -vvv  # Extra verbose output
```

### Testnet/Mainnet Deployment

#### Base Sepolia (Testnet)
```bash
forge script script/Deploy.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  --private-key $PRIVATE_KEY
```

#### Base Mainnet
```bash
forge script script/Deploy.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  --verify \
  --private-key $PRIVATE_KEY
```

### Interacting with Deployed Contract

After deployment, you can interact with the contract using `cast`:

```bash
# Get contract info
cast call <CONTRACT_ADDRESS> "getVersion()" --rpc-url http://localhost:8545

# Get charity count
cast call <CONTRACT_ADDRESS> "getCharityCount()" --rpc-url http://localhost:8545

# Make a donation (0.1 ETH to first charity)
cast send <CONTRACT_ADDRESS> \
  "donate(address)" <CHARITY_ADDRESS> \
  --value 0.1ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://localhost:8545

# Donate by name
cast send <CONTRACT_ADDRESS> \
  "donateByName(string)" "American Red Cross" \
  --value 0.5ether \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://localhost:8545
```

## Contract Interface

### Core Functions

```solidity
// Donate to charity by address
function donate(address _charityAddress) external payable

// Donate to charity by name
function donateByName(string memory _charityName) external payable

// Admin: Add single charity
function addCharity(string memory _name, address payable _walletAddress) external

// Admin: Add multiple charities
function addCharitiesBatch(string[] memory _names, address payable[] memory _walletAddresses) external
```

### View Functions

```solidity
// Get charity by address
function getCharityByAddress(address _charityAddress) external view returns (Charity memory)

// Get charity by name
function getCharityByName(string memory _name) external view returns (Charity memory)

// Get all registered charities
function getAllCharities() external view returns (address[] memory)

// Get charity statistics
function getCharityStats(address _charityAddress) external view returns (
    string memory name_,
    bool isActive_,
    uint256 totalEthReceived_,
    uint256 donationCount_,
    uint256 registeredAt_
)

// Get total platform statistics
function getTotalStats() external view returns (
    uint256 totalCharities_,
    uint256 activeCharities_,
    uint256 totalDonations_,
    uint256 totalEthRouted_,
    uint256 averageDonationSize_
)

// Validation helpers
function isValidCharity(address _charityAddress) external view returns (bool)
function isValidCharityName(string memory _charityName) external view returns (bool)
```

## Events

```solidity
event DonationRouted(
    uint256 indexed donationId,
    address indexed donor,
    address indexed charity,
    uint256 amount,
    string charityName
);

event CharityAdded(
    address indexed charityAddress,
    string name,
    uint256 timestamp
);

event CharityUpdated(
    address indexed charityAddress,
    string oldName,
    string newName
);

event CharityRemoved(
    address indexed charityAddress,
    string name
);

event CharityStatusChanged(
    address indexed charityAddress,
    bool isActive
);
```

## Security Features

- **ReentrancyGuard**: Protection against reentrancy attacks
- **Access Control**: Admin-only charity management using OpenZeppelin's Ownable2Step
- **Input Validation**: Comprehensive parameter validation
- **Zero Address Protection**: Prevents operations on removed charities
- **Direct Transfer**: Immediate ETH routing to charities
- **Custom Errors**: Gas-efficient, descriptive error handling

## Gas Optimization

- **No Storage**: Donations don't store transaction data on-chain
- **Packed Structs**: Optimized storage layout
- **Custom Errors**: Gas-efficient error handling vs require strings
- **Batch Operations**: Efficient multi-charity registration
- **Direct Routing**: No intermediate storage or complex logic

## Test Coverage

The project includes comprehensive test suites covering:

- **Basic functionality** (ownership, charity CRUD operations)
- **Donation mechanics** (both by address and by name)
- **Batch operations** and edge cases
- **View functions** and statistics accuracy
- **Security features** (reentrancy protection, access control)
- **Error handling** and validation
- **Integration scenarios** and complex workflows

```bash
# Run specific test suites
forge test --match-contract CharityRouterTest              # Basic functionality
forge test --match-contract CharityRouterDonationTest      # Donation features  
forge test --match-contract CharityRouterStep8Test         # Donation by name
forge test --match-contract CharityRouterViewFunctionsTest # View functions & stats
```

## Project Structure

```
├── src/
│   └── CharityRouter.sol          # Main contract
├── test/
│   ├── CharityRouter.t.sol        # Basic functionality tests
│   ├── CharityRouterStep4.t.sol   # Charity management tests
│   ├── CharityRouterStep5.t.sol   # Batch operations tests
│   ├── CharityRouterDonation.t.sol # Donation functionality tests
│   ├── CharityRouterStep8.t.sol   # Donation by name tests
│   └── CharityRouterViewFunctions.t.sol # View functions tests
├── script/
│   └── Deploy.s.sol               # Deployment script
└── foundry.toml                   # Foundry configuration
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with comprehensive tests
4. Run the full test suite (`forge test`)
5. Format code (`forge fmt`)
6. Submit a pull request

## License

MIT

## Roadmap

### V1 (Current) ✅
- [x] ETH donation routing
- [x] Charity management (CRUD operations)
- [x] Event tracking and transparency
- [x] Batch operations for efficiency
- [x] Donation by name functionality
- [x] Comprehensive view functions and statistics
- [x] Security hardening and access control

### V2 (Planned)
- [ ] ERC20 token support (USDC, USDT)
- [ ] USD price oracle integration
- [ ] Enhanced analytics and reporting
- [ ] Multi-signature admin support
- [ ] Charity verification system
- [ ] Donation matching/multiplier features

## Foundry Commands Reference

### Build & Test
```shell
forge build                # Compile contracts
forge test                 # Run all tests
forge test -vv             # Verbose test output
forge test --gas-report    # Include gas usage
forge coverage             # Test coverage report
forge fmt                  # Format code
```

### Development
```shell
anvil                      # Start local blockchain
forge script <script>     # Run deployment script
cast <command>             # Interact with contracts
```

### Deployment
```shell
# Local deployment
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <key>

# Testnet deployment
forge script script/Deploy.s.sol --rpc-url <testnet_url> --broadcast --verify --private-key <key>
```

### Help
```shell
forge --help
anvil --help  
cast --help
```
