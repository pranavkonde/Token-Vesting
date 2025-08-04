const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  // Deploy MyToken with 1 billion tokens (18 decimals)
  const initialTokenSupply = hre.ethers.parseEther("1000000000"); // 1B tokens with 18 decimals
  const MyToken = await hre.ethers.getContractFactory("MyToken");
  const myToken = await MyToken.deploy(initialTokenSupply);
  await myToken.waitForDeployment();
  console.log(`MyToken deployed to: ${myToken.target}`);

  // Deploy TokenVesting
  const TokenVesting = await hre.ethers.getContractFactory("TokenVesting");
  const tokenVesting = await TokenVesting.deploy(myToken.target);
  await tokenVesting.waitForDeployment();
  console.log(`TokenVesting deployed to: ${tokenVesting.target}`);

  // Transfer tokens to the vesting contract for future schedules
  const tokensForVesting = hre.ethers.parseEther("100000000"); // 100M tokens
  await myToken.transfer(tokenVesting.target, tokensForVesting);
  console.log(`Transferred ${hre.ethers.formatEther(tokensForVesting)} tokens to TokenVesting contract`);

  // Example vesting schedule: 1M tokens over 2 years with 6-month cliff
  const beneficiaryAddress = deployer.address;
  const now = Math.floor(Date.now() / 1000);
  const sixMonths = 180 * 24 * 60 * 60;
  const twoYears = 2 * 365 * 24 * 60 * 60;
  const vestingAmount = hre.ethers.parseEther("1000000"); // 1M tokens

  await tokenVesting.createVestingSchedule(
    beneficiaryAddress,
    now + sixMonths, // cliff
    now,             // start
    twoYears,        // duration
    vestingAmount    // amount
  );
  console.log(`Created vesting schedule for ${beneficiaryAddress} with ${hre.ethers.formatEther(vestingAmount)} tokens`);

  console.log("\nDeployment Summary:");
  console.log("==================");
  console.log(`MyToken: ${myToken.target}`);
  console.log(`TokenVesting: ${tokenVesting.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});