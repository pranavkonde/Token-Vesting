# Token Vesting Smart Contract Development Guide

This guide walks you through the process of building a token vesting smart contract system using Hardhat, Solidity, and deploying it to Rootstock Testnet.

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
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox @openzeppelin/contracts dotenv
```

3. Initialize Hardhat project:
```bash
npx hardhat init
```
Choose "Create a JavaScript project" when prompted.

4. .env:
```bash
PRIVATE_KEY= Your Private Key
RSK_TESTNET_RPC_URL=https://public-node.testnet.rsk.co
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

1. Create the MyToken contract (`contracts/MyToken.sol`):
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor(uint256 initialSupply) ERC20("Reward Token", "RVT") {
        _mint(msg.sender, initialSupply);
    }
}
```

2. Create the TokenVesting contract (`contracts/TokenVesting.sol`):
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    struct VestingSchedule {
        uint256 start;
        uint256 cliffDuration;
        uint256 duration;
        uint256 slicePeriodSeconds;
        uint256 amountTotal;
        uint256 released;
        bool revocable;
        address beneficiary;
    }

    IERC20 public immutable token;
    mapping(uint256 => VestingSchedule) public vestingSchedules;
    uint256 public vestingSchedulesTotalAmount;
    uint256 public vestingSchedulesIds;

    event Released(uint256 indexed scheduleId, address indexed beneficiary, uint256 amount);
    event Revoked(uint256 indexed scheduleId);
    event VestingScheduleCreated(uint256 indexed scheduleId, address indexed beneficiary, uint256 start, uint256 cliffDuration, uint256 duration, uint256 slicePeriodSeconds, uint256 amount, bool revocable);

    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "Token address cannot be zero");
        token = IERC20(_token);
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliffDuration,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount
    ) public onlyOwner {
        require(_beneficiary != address(0), "Beneficiary address cannot be zero");
        require(_amount > 0, "Amount must be greater than 0");
        require(_duration > 0, "Duration must be greater than 0");
        require(_slicePeriodSeconds >= 1, "Slice period must be greater than 0");
        require(_duration >= _cliffDuration, "Duration must be greater than cliff duration");

        uint256 scheduleId = vestingSchedulesIds;
        vestingSchedules[scheduleId] = VestingSchedule({
            start: _start,
            cliffDuration: _cliffDuration,
            duration: _duration,
            slicePeriodSeconds: _slicePeriodSeconds,
            amountTotal: _amount,
            released: 0,
            revocable: _revocable,
            beneficiary: _beneficiary
        });

        vestingSchedulesTotalAmount += _amount;
        vestingSchedulesIds++;

        emit VestingScheduleCreated(
            scheduleId,
            _beneficiary,
            _start,
            _cliffDuration,
            _duration,
            _slicePeriodSeconds,
            _amount,
            _revocable
        );
    }

    function release(uint256 _scheduleId) public {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(schedule.beneficiary == msg.sender || owner() == msg.sender, "Only beneficiary or owner can release tokens");
        require(schedule.amountTotal > 0, "Vesting schedule does not exist");

        uint256 releasableAmount = computeReleasableAmount(_scheduleId);
        require(releasableAmount > 0, "No tokens to release");

        schedule.released += releasableAmount;
        vestingSchedulesTotalAmount -= releasableAmount;

        require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");

        emit Released(_scheduleId, schedule.beneficiary, releasableAmount);
    }

    function revoke(uint256 _scheduleId) public onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        require(schedule.amountTotal > 0, "Vesting schedule does not exist");
        require(schedule.revocable, "Vesting schedule is not revocable");

        uint256 releasableAmount = computeReleasableAmount(_scheduleId);
        uint256 nonVestedAmount = schedule.amountTotal - schedule.released - releasableAmount;

        schedule.released += releasableAmount;
        vestingSchedulesTotalAmount -= (releasableAmount + nonVestedAmount);

        if (releasableAmount > 0) {
            require(token.transfer(schedule.beneficiary, releasableAmount), "Token transfer failed");
        }

        if (nonVestedAmount > 0) {
            require(token.transfer(owner(), nonVestedAmount), "Token transfer failed");
        }

        emit Revoked(_scheduleId);
    }

    function computeReleasableAmount(uint256 _scheduleId) public view returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[_scheduleId];
        if (block.timestamp < schedule.start + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.start + schedule.duration) {
            return schedule.amountTotal - schedule.released;
        }

        uint256 timeFromStart = block.timestamp - schedule.start;
        uint256 secondsPerSlice = schedule.slicePeriodSeconds;
        uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
        uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
        uint256 vestedAmount = (schedule.amountTotal * vestedSeconds) / schedule.duration;

        return vestedAmount - schedule.released;
    }
}
```

## Configuration

1. Create a `.env` file in the root directory:
```
RSK_TESTNET_RPC_URL=https://public-node.testnet.rsk.co/
PRIVATE_KEY=your_private_key_here
```

2. Update `hardhat.config.js`:
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

## Deployment Script

Create `scripts/deploy.js`:
```javascript
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  const initialTokenSupply = hre.ethers.parseEther("1000000000"); // 1 Billion tokens

  // Deploy MyToken
  const MyToken = await hre.ethers.getContractFactory("MyToken");
  const myToken = await MyToken.deploy(initialTokenSupply);
  await myToken.waitForDeployment();
  console.log(`MyToken deployed to: ${myToken.target}`);

  // Deploy TokenVesting
  const TokenVesting = await hre.ethers.getContractFactory("TokenVesting");
  const tokenVesting = await TokenVesting.deploy(myToken.target);
  await tokenVesting.waitForDeployment();
  console.log(`TokenVesting deployed to: ${tokenVesting.target}`);

  // Transfer some tokens to the vesting contract
  const tokensToFundVestingContract = hre.ethers.parseEther("100000000"); // 100 million tokens
  await myToken.transfer(tokenVesting.target, tokensToFundVestingContract);
  console.log(`Transferred ${hre.ethers.formatEther(tokensToFundVestingContract)} RVT to TokenVesting contract`);

  // Example of creating a vesting schedule
  const beneficiaryAddress = deployer.address;
  const currentTime = Math.floor(Date.now() / 1000);
  const cliffTime = currentTime + (30 * 24 * 60 * 60); // 30 days cliff
  const startTime = cliffTime;
  const duration = (2 * 365 * 24 * 60 * 60); // 2 years duration
  const vestingAmount = hre.ethers.parseEther("1000000"); // 1 million RVT

  await tokenVesting.createVestingSchedule(
    beneficiaryAddress,
    cliffTime,
    startTime,
    duration,
    vestingAmount
  );
  console.log(`Created a vesting schedule for ${beneficiaryAddress} with ${hre.ethers.formatEther(vestingAmount)} RVT.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
```

## Testing

1. Compile the contracts:
```bash
npx hardhat compile
```

2. Run tests:
```bash
npx hardhat test
```

## Deployment

1. Get test RBTC from the Rootstock Testnet faucet:
   - Visit: https://faucet.testnet.rsk.co/
   - Enter your wallet address to receive test RBTC

2. Deploy to Rootstock Testnet:
```bash
npx hardhat run scripts/deploy.js --network rskTestnet
```

## Contract Interaction

After deployment, you can interact with the contracts using Hardhat console or by writing scripts. Here's an example of how to interact with the contracts:

```javascript
// Connect to the deployed contracts
const myToken = await ethers.getContractAt("MyToken", "DEPLOYED_MYTOKEN_ADDRESS");
const tokenVesting = await ethers.getContractAt("TokenVesting", "DEPLOYED_TOKENVESTING_ADDRESS");

// Check token balance
const balance = await myToken.balanceOf("YOUR_ADDRESS");
console.log("Balance:", ethers.formatEther(balance));

// Create a new vesting schedule
await tokenVesting.createVestingSchedule(
  "BENEFICIARY_ADDRESS",
  startTime,
  cliffDuration,
  duration,
  amount
);

// Release vested tokens
await tokenVesting.release(scheduleId);
```


## Additional Resources

- [Hardhat Documentation](https://hardhat.org/getting-started/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)
- [Rootstock Documentation](https://developers.rsk.co/)
- [Solidity Documentation](https://docs.soliditylang.org/)


