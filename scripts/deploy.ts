import {
  ERC20__factory,
  PlaceholderToken__factory,
  Presale__factory,
  PresaleRouter__factory,
} from "../typechain-types";
import { Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { config, makeRounds } from "../config";
import environment from "../environment";

console.log(environment);

async function main() {
  const [signer] = await ethers.getSigners();

  const presaleAsset = ERC20__factory.connect(environment.presaleAsset, signer);
  const { totalTokenAllocation, rounds } = makeRounds(
    Number(await presaleAsset.decimals())
  );

  const presaleFactory = new Presale__factory(signer as unknown as Signer);
  const placeholderFactory = new PlaceholderToken__factory(
    signer as unknown as Signer
  );
  const presaleRouterFactory = new PresaleRouter__factory(
    signer as unknown as Signer
  );

  const presaleToken = await placeholderFactory.deploy(
    signer.address,
    totalTokenAllocation
  );

  console.log("PresaleToken @ ", presaleToken.address);
  await presaleToken.deployed();

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

  // goerli configuration
  console.log("deploying router");

  const presaleRouter = await presaleRouterFactory.deploy(
    presale.address,
    environment.referrals
  );

  console.log(`PresaleRouter @ ${presaleRouter.address}`);
  await presaleRouter.deployed();

  console.log("verifying");

  await new Promise((res) => setTimeout(res, 30000));

  await hre.run("verify:verify", {
    constructorArguments: [signer.address, totalTokenAllocation.toString()],
    address: presaleToken.address,
  });

  await hre.run("verify:verify", {
    address: presale.address,
    constructorArguments: [
      environment.presaleAsset,
      presaleToken.address,
      environment.owner,
    ],
  });

  await hre.run("verify:verify", {
    address: presaleRouter.address,
    constructorArguments: [presale.address, environment.referrals],
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
