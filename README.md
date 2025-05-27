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
```

### Local Development

```bash
# Start local testnet
anvil

# Deploy to local testnet
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <your-private-key>
```

### Deployment

#### Base Sepolia (Testnet)
```bash
forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify --private-key $PRIVATE_KEY
```

#### Base Mainnet
```bash
forge script script/Deploy.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify --private-key $PRIVATE_KEY
```

### Adding Charities

```bash
# Add charities in batch
forge script script/AddCharities.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --private-key $PRIVATE_KEY
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
```

## Security Features

- **ReentrancyGuard**: Protection against reentrancy attacks
- **Access Control**: Admin-only charity management
- **Input Validation**: Comprehensive parameter validation
- **Zero Address Protection**: Prevents operations on removed charities
- **Direct Transfer**: Immediate ETH routing to charities

## Gas Optimization

- **No Storage**: Donations don't store transaction data
- **Packed Structs**: Optimized storage layout
- **Custom Errors**: Gas-efficient error handling
- **Batch Operations**: Efficient multi-charity registration

## Project Structure

```
├── src/
│   ├── CharityRouter.sol          # Main contract
│   └── interfaces/
│       └── ICharityRouter.sol     # Contract interface
├── test/
│   ├── CharityRouter.t.sol        # Main test file
│   └── utils/
│       └── TestHelpers.sol        # Test utilities
├── script/
│   ├── Deploy.s.sol               # Deployment script
│   └── AddCharities.s.sol         # Charity management script
└── foundry.toml                   # Foundry configuration
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Run the full test suite
5. Submit a pull request

## License

MIT

## Roadmap

### V1 (Current)
- [x] ETH donation routing
- [x] Charity management
- [x] Event tracking
- [x] Batch operations

### V2 (Planned)
- [ ] ERC20 token support (USDC)
- [ ] USD price oracle integration
- [ ] Enhanced analytics
- [ ] Multi-signature admin support

## Foundry Commands Reference

### Build
```shell
forge build
```

### Test
```shell
forge test
```

### Format
```shell
forge fmt
```

### Gas Snapshots
```shell
forge snapshot
```

### Local Node
```shell
anvil
```

### Deploy
```shell
forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast (Blockchain Interaction)
```shell
cast <subcommand>
```

### Help
```shell
forge --help
anvil --help
cast --help
```
