import { Presale__factory } from "../typechain-types";
import { BigNumber, Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { rounds } from "../config";

async function main() {
  const [signer] = await ethers.getSigners();
  const presaleFactory = new Presale__factory(signer as unknown as Signer);

  const args: Parameters<Presale__factory["deploy"]> = [
    "0x6DAd753739Ef6a20bbBcA2BEc6E11C8047517078",
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

  console.log(`Deployed to ${presale.address}`);

  await presale.deployed();

  await new Promise((res) => setTimeout(res, 30000));

  console.log("verifying");

  await hre.run("verify:verify", {
    address: presale.address,
    constructorArguments: args,
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
