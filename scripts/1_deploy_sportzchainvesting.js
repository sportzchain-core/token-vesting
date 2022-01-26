// scripts/deploy_sportzchain.js
const { ethers, upgrades } = require('hardhat');

async function main () {
  const _name = 'Sample Token';
  const _symbol = 'SPN';
  const _decimals = 18;
  const _totalSupply = 10 * (10 ** 9);

  console.log('Deploying Sample Token...');
  const SampleToken = await ethers.getContractFactory("SampleToken");
  token = await SampleToken.deploy(_name,_symbol,_decimals, _totalSupply);
  console.log('Sample Token deployed to:', token.address);

  console.log('Deploying Vesting Contract...');
  const SportZchainTokenVesting = await ethers.getContractFactory("SportZchainTokenVesting");
  vesting = await SportZchainTokenVesting.deploy(token.address);
  console.log('Vesting Contract deployed to:', vesting.address);
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
