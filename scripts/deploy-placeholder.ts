import { PlaceholderToken__factory } from "../typechain-types";
import { BigNumber, Signer } from "ethers";
import hre, { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners();

  const placeholderFactory = new PlaceholderToken__factory(
    signer as unknown as Signer
  );

  const totalTokenAllocation = BigNumber.from(10).pow(8).mul(6_000_000); // 6_000_000 tokens
  const presaleToken = await placeholderFactory.deploy(
    signer.address,
    totalTokenAllocation
  );

  console.log("PresaleToken @ ", presaleToken.address);
  await presaleToken.deployed();

  console.log("verifying");

  await new Promise((res) => setTimeout(res, 30000));

  await hre.run("verify:verify", {
    constructorArguments: [signer.address, totalTokenAllocation.toString()],
    address: presaleToken.address,
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
