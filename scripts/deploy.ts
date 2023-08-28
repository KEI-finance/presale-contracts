import {
  PlaceholderToken,
  PlaceholderToken__factory,
  Presale,
  Presale__factory,
  PresaleRouter__factory,
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
  const presaleRouterFactory = new PresaleRouter__factory(
    signer as unknown as Signer
  );

  let presaleToken: PlaceholderToken | undefined;
  let presale: Presale | undefined;
  if (environment.chainId === environment.presaleChainId) {
    presaleToken = await placeholderFactory.deploy(
      signer.address,
      totalTokenAllocation
    );

    console.log("PresaleToken @ ", presaleToken.address);
    await presaleToken.deployed();

    presale = await presaleFactory.deploy(
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
      .initialize(environment.swapRouter, config, rounds)
      .then((tx) => tx.wait());
  }

  // goerli configuration

  const presaleRouter = await presaleRouterFactory.deploy(
    environment.chainId,
    environment.presaleChainId,
    environment.stargatePoolId,
    environment.stargateGas,
    presale?.address || environment.presale,
    environment.swapRouter,
    environment.stargateRouter,
    environment.stargateReceiver
  );

  console.log(`PresaleRouter @ ${presaleRouter.address}`);
  await presaleRouter.deployed();

  console.log("verifying");

  await new Promise((res) => setTimeout(res, 30000));

  if (presaleToken) {
    await hre.run("verify:verify", {
      constructorArguments: [signer.address, totalTokenAllocation.toString()],
      address: presaleToken.address,
    });
  }

  if (presale) {
    await hre.run("verify:verify", {
      address: presale.address,
      constructorArguments: [
        environment.presaleAsset,
        presaleToken.address,
        environment.owner,
      ],
    });
  }

  await hre.run("verify:verify", {
    address: presaleRouter.address,
    constructorArguments: [
      environment.chainId,
      environment.presaleChainId,
      environment.stargatePoolId,
      environment.stargateGas,
      presale?.address || environment.presale,
      environment.swapRouter,
      environment.stargateRouter,
      environment.stargateReceiver,
    ],
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
