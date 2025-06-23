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
  const beneficiaryAddress = deployer.address; // Using deployer as beneficiary for example
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