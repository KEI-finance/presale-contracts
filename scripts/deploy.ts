import {PlaceholderToken__factory, Presale, Presale__factory, PresaleRouter__factory} from "../typechain-types";
import { BigNumber, Signer } from "ethers";
import hre, { ethers } from "hardhat";
import {rounds, totalTokenAllocation} from "../config";

async function main() {
  const [signer] = await ethers.getSigners();
  const presaleFactory = new Presale__factory(signer as unknown as Signer);
  const presaleRouterFactory = new PresaleRouter__factory(signer as unknown as Signer);
  const placeholderFactory = new PlaceholderToken__factory(signer as unknown as Signer);

  const swapRouter = '0xE592427A0AEce92De3Edee1F18E0157C05861564';
  const presaleAsset = '0x2039f3B58ed4a8EDe1B6C8f43aC4c3DEe3187f7b';
  const withdrawTo = '0x921d360aD22A6D0289ce57fcb8250e299cB19EA3';
  const initializeArgs: Parameters<Presale["initialize"]> = [
    withdrawTo,
    {
      minDepositAmount: 0,
      maxUserAllocation: BigNumber.from(10).pow(14),
      startDate: Math.round(Date.now() / 1000) + 60,
    },
    rounds,
  ];

  const presaleToken = await placeholderFactory.deploy(signer.address, totalTokenAllocation);

  console.log('PresaleToken @ ', presaleToken.address);

  await presaleToken.deployed();

  // goerli configuration
  const presale = await presaleFactory.deploy(presaleAsset, presaleToken.address);

  console.log(`Presale @ ${presale.address}`);

  await presale.deployed();

  const presaleRouter = await presaleRouterFactory.deploy(presale.address, swapRouter);

  console.log(`PresaleRouter @ ${presaleRouter.address}`);

  await presaleRouter.deployed();

  await presaleToken.approve(presale.address, totalTokenAllocation).then(tx => tx.wait());
  await presale.initialize(...initializeArgs).then(tx => tx.wait());

  await new Promise((res) => setTimeout(res, 30000));

  console.log("verifying");

  await hre.run("verify:verify", {
    address: presaleToken.address,
    constructorArguments: [signer.address, totalTokenAllocation.toString()],
  });

  await hre.run("verify:verify", {
    address: presale.address,
    constructorArguments: [presaleAsset, presaleToken.address],
  });

  await hre.run("verify:verify", {
    address: presaleRouter.address,
    constructorArguments: [presale.address, swapRouter],
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
