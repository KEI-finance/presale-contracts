import {
  PlaceholderToken__factory,
  Presale__factory,
  PresaleRouter__factory,
  PresaleStargate__factory,
} from "../typechain-types";
import { Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { config, rounds, totalTokenAllocation } from "../config";
import environment from "../environment";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

async function deployStargateContracts(
  signer: HardhatEthersSigner,
  stargate: (typeof environment)["stargate"]
) {
  const stargateFactory = new PresaleStargate__factory(
    signer as unknown as Signer
  );

  const presaleStargate = await stargateFactory.deploy(
    stargate.presaleChainId,
    stargate.stargatePoolId,
    stargate.stargateGas,
    stargate.presaleAsset,
    stargate.swapRouter,
    stargate.presaleRouter,
    stargate.stargateRouter
  );

  console.log("Stargate @", presaleStargate.address);

  await presaleStargate.deployed();

  console.log("verifying");

  await hre.run("verify:verify", {
    address: presaleStargate.address,
    constructorArguments: [
      stargate.presaleChainId,
      stargate.stargatePoolId,
      stargate.stargateGas,
      stargate.presaleAsset,
      stargate.swapRouter,
      stargate.presaleRouter,
      stargate.stargateRouter,
    ],
  });
}

async function main() {
  const [signer] = await ethers.getSigners();

  const { presale, stargate } = environment;

  if (presale.withdrawTo) {
    await deployPresaleContracts(signer, presale);
  }

  if (stargate.presaleRouter) {
    await deployStargateContracts(signer, stargate);
  }

  console.log("completed");
}

async function deployPresaleContracts(
  signer: HardhatEthersSigner,
  env: (typeof environment)["presale"]
) {
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

  await new Promise((res) => setTimeout(res, 30000));

  // goerli configuration
  const presale = await presaleFactory.deploy(
    env.presaleAsset,
    presaleToken.address,
    env.owner
  );

  console.log(`Presale @ ${presale.address}`);

  await presale.deployed();

  console.log("approving");
  await presaleToken
    .approve(presale.address, totalTokenAllocation)
    .then((tx) => tx.wait());

  console.log("initializing");

  await presale
    .initialize(env.withdrawTo, config, rounds)
    .then((tx) => tx.wait());

  const presaleRouter = await presaleRouterFactory.deploy(presale.address);

  console.log("PresaleRouter @", presaleRouter.address);

  await presaleRouter.deployed();

  console.log("verifying");

  await new Promise((res) => setTimeout(res, 30000));

  await hre.run("verify:verify", {
    address: presaleToken.address,
    constructorArguments: [signer.address, totalTokenAllocation.toString()],
  });

  await hre.run("verify:verify", {
    address: presale.address,
    constructorArguments: [env.presaleAsset, presaleToken.address, env.owner],
  });

  await hre.run("verify:verify", {
    address: presaleRouter.address,
    constructorArguments: [presale.address],
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
