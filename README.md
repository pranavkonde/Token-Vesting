# Token Vesting Smart Contract Development

Building a token vesting smart contract system using Hardhat, Solidity, and deploying it to Rootstock Testnet.

## Prerequisites

- Node.js (v14 or higher)
- npm or yarn
- MetaMask wallet
- Basic understanding of Solidity and Ethereum development

## Project Setup

1. Create a new directory and initialize the project:
```bash
mkdir token-vesting
cd token-vesting
npm init -y
```

2. Install Hardhat and required dependencies:
```bash
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npm install @openzeppelin/contracts@5.0.1 dotenv
```

3. Initialize Hardhat project:
```bash
npx hardhat init
```
Choose "Create a JavaScript project" when prompted.

4. Create a `.env` file:
```bash
PRIVATE_KEY=your_private_key_here
RSK_TESTNET_RPC_URL=https://public-node.testnet.rootstock.io
```

## Project Structure

```
token-vesting/
├── contracts/
│   ├── MyToken.sol
│   └── TokenVesting.sol
├── scripts/
│   └── deploy.js
├── test/
├── .env
├── hardhat.config.js
└── package.json
```

## Smart Contract Development

The project includes two main contracts:

1. `MyToken.sol`: A standard ERC20 token for testing the vesting contract
2. `TokenVesting.sol`: The main vesting contract with the following features:
   - Linear vesting with cliff period
   - Multiple vesting schedules per beneficiary
   - Revocable schedules (unvested tokens returned to treasury)
   - Gas-optimized storage layout
   - Emergency token recovery functions

## Configuration

1. Update `hardhat.config.js`:
```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RSK_TESTNET_RPC = process.env.RSK_TESTNET_RPC_URL;

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    rskTestnet: {
      url: RSK_TESTNET_RPC,
      chainId: 31,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
      gasPrice: 60000000,
    },
    hardhat: {
      chainId: 31337,
    }
  },
};
```

## Testing

The test suite includes comprehensive tests for all vesting scenarios:

- Cliff period not reached
- Partial linear vesting
- Complete vesting
- Schedule revocation
- Double-claim prevention

Run the tests:
```bash
npx hardhat test
```

## Deployment

1. Get test RBTC from the Rootstock Testnet faucet:
   - Visit: https://faucet.testnet.rootstock.io/
   - Enter your wallet address to receive test RBTC

2. Deploy to Rootstock Testnet:
```bash
npx hardhat run scripts/deploy.js --network rskTestnet
```

## Contract Interaction

After deployment, you can interact with the contracts using Hardhat console or scripts:

```javascript
// Connect to the deployed contracts
const myToken = await ethers.getContractAt("MyToken", "DEPLOYED_MYTOKEN_ADDRESS");
const tokenVesting = await ethers.getContractAt("TokenVesting", "DEPLOYED_TOKENVESTING_ADDRESS");

// Create a new vesting schedule (1 million tokens over 2 years with 6-month cliff)
const amount = ethers.parseEther("1000000"); // 1M tokens with 18 decimals
const now = Math.floor(Date.now() / 1000);
const sixMonths = 180 * 24 * 60 * 60;
const twoYears = 2 * 365 * 24 * 60 * 60;

await tokenVesting.createVestingSchedule(
  beneficiaryAddress,
  now + sixMonths, // cliff
  now,             // start
  twoYears,        // duration
  amount           // total amount
);

// Release vested tokens
await tokenVesting.release(scheduleId);
```

## Additional Resources

- [Hardhat Documentation](https://hardhat.org/getting-started/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Rootstock Documentation](https://developers.rootstock.io/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## License

This project is licensed under the MIT License - see the LICENSE file for details.