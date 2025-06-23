require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const MNEMONIC = process.env.MNEMONIC;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
const RSK_TESTNET_RPC = process.env.RSK_TESTNET_RPC_URL || "https://public-node.testnet.rsk.co/";
const RSK_MAINNET_RPC = process.env.RSK_MAINNET_RPC_URL || "https://public-node.rsk.co/";

/** @type import('hardhat/config').HardhatUserConfig */
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
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : (MNEMONIC ? { mnemonic: MNEMONIC } : []),
      gasPrice: 100000000,
    },
    rskMainnet: {
      url: RSK_MAINNET_RPC,
      chainId: 30,
      accounts: PRIVATE_KEY ? [PRIVATE_KEY] : (MNEMONIC ? { mnemonic: MNEMONIC } : []),
      gasPrice: 100000000,
    },
    hardhat: {
      chainId: 31337,
    }
  },
}; 