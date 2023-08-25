import {Presale__factory, PresaleRouter__factory} from "../typechain-types";
import { BigNumber, Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { rounds } from "../config";

async function main() {
  const [signer] = await ethers.getSigners();
  const presaleFactory = new Presale__factory(signer as unknown as Signer);
  const presaleRouterFactory = new PresaleRouter__factory(signer as unknown as Signer);

  const swapRouter = '0xE592427A0AEce92De3Edee1F18E0157C05861564';
  const args: Parameters<Presale__factory["deploy"]> = [
    "0x2039f3B58ed4a8EDe1B6C8f43aC4c3DEe3187f7b",
    {
      minDepositAmount: 0,
      maxUserAllocation: BigNumber.from(10).pow(14),
      startDate: Math.round(Date.now() / 1000) + 60,
      withdrawTo: "0x921d360aD22A6D0289ce57fcb8250e299cB19EA3",
    },
    rounds,
  ];

  // goerli configuration
  const presale = await presaleFactory.deploy(...args);

  console.log(`Presale @ ${presale.address}`);

  await presale.deployed();

  const presaleRouter = await presaleRouterFactory.deploy(presale.address, swapRouter);

  console.log(`PresaleRouter @ ${presaleRouter.address}`);

  await presaleRouter.deployed();

  await new Promise((res) => setTimeout(res, 30000));

  console.log("verifying");

  await hre.run("verify:verify", {
    address: presale.address,
    constructorArguments: args,
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
