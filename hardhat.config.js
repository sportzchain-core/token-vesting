require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-etherscan");

//const { alchemyApiKey, mnemonic_bsc } = require('./secrets.json');

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.2",
    settings: {
      optimizer: {
        enabled: false,
        runs: 200
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  },
	networks: {
    'rinkeby': {
      url: "http://localhost:24012/rpc",
      timeout: 60000
    }
	},
  gasReporter: {
    enabled: (process.env.REPORT_GAS) ? true : false,
    token: 'ETH',
    gasPriceApi: 'https://api.etherscan.io/api?module=proxy&action=eth_gasPrice',
    // gasPrice: 2.857531333,
    currency: 'USD',
    coinmarketcap: process.env.COINMARKETCAP_API_KEY
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: {
      'rinkeby': process.env.ETHERSCAN_API_KEY,
    }
  }
};
