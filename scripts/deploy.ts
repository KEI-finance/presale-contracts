import {
  PlaceholderToken__factory,
  Presale,
  Presale__factory,
} from "../typechain-types";
import { BigNumber, Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { rounds, totalTokenAllocation } from "../config";
import environment from "../environment";

console.log(environment);
async function main() {
  const [signer] = await ethers.getSigners();
  const presaleFactory = new Presale__factory(signer as unknown as Signer);
  const placeholderFactory = new PlaceholderToken__factory(
    signer as unknown as Signer
  );

  const initializeArgs: Parameters<Presale["initialize"]> = [
    environment.swapRouter,
    {
      minDepositAmount: 0,
      maxUserAllocation: BigNumber.from(10).pow(14),
      startDate: BigNumber.from(Math.round(Date.now() / 1000)).add(300),
    },
    rounds,
  ];

  const presaleToken = await placeholderFactory.deploy(
    signer.address,
    totalTokenAllocation
  );

  console.log("PresaleToken @ ", presaleToken.address);

  await presaleToken.deployed();

  // goerli configuration
  const presale = await presaleFactory.deploy(
    environment.presaleAsset,
    presaleToken.address,
    environment.owner
  );

  console.log(`Presale @ ${presale.address}`);

  await presale.deployed();

  console.log("approving");
  await presaleToken
    .approve(presale.address, totalTokenAllocation)
    .then((tx) => tx.wait());

  console.log("approved");

  await presale.initialize(...initializeArgs).then((tx) => tx.wait());

  console.log("initialized");

  await new Promise((res) => setTimeout(res, 30000));

  console.log("verifying");

  await hre.run("verify:verify", {
    address: presaleToken.address,
    constructorArguments: [signer.address, totalTokenAllocation.toString()],
  });

  await hre.run("verify:verify", {
    address: presale.address,
    constructorArguments: [environment.presaleAsset, presaleToken.address],
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
