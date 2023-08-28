import {
  PlaceholderToken__factory,
  Presale__factory, PresaleRouter__factory,
} from "../typechain-types";
import { Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { config, rounds, totalTokenAllocation } from "../config";
import environment from "../environment";

async function main() {
  const [signer] = await ethers.getSigners();
  const presaleFactory = new Presale__factory(signer as unknown as Signer);
  const placeholderFactory = new PlaceholderToken__factory(
    signer as unknown as Signer
  );
  const presaleRouterFactory = new PresaleRouter__factory(signer as unknown as Signer);

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

  console.log("initializing");

  await presale
    .initialize(environment.withdrawTo, config, rounds)
    .then((tx) => tx.wait());

  console.log("verifying");

  await new Promise((res) => setTimeout(res, 30000));

  await hre.run("verify:verify", {
    address: presaleToken.address,
    constructorArguments: [signer.address, totalTokenAllocation.toString()],
  });

  await hre.run("verify:verify", {
    address: presale.address,
    constructorArguments: [
      environment.presaleAsset,
      presaleToken.address,
      environment.owner,
    ],
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
