import { ethers } from "hardhat";
async function main() {
  const preSale = await ethers.deployContract("PreSale", [], {});

  await preSale.waitForDeployment();

  console.log(
    `Deployed to ${preSale.target}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
