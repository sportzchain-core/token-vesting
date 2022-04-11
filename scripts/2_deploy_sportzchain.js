async function main() {
  const TokenVestingClone = await ethers.getContractFactory("TokenVestingClone");

  /*
  Note: address used here as constructor argument is of SPN token(Etehreum mainnet).
  change it before deploying on testnet.
  */
  const TokenVestingClone_deployed = await TokenVestingClone.deploy('0x32EA3Dc70E2962334864A9665254d2433E4ddbfD');

  console.log("TokenVestingClone deployed to:", TokenVestingClone_deployed.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
      console.error(error);
      process.exit(1);
  });