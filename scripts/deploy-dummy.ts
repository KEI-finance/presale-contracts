import {
  DummyContract__factory,
  PlaceholderToken__factory,
  Presale,
  Presale__factory,
  PresaleRouter__factory,
} from "../typechain-types";
import { BigNumber, Signer } from "ethers";
import hre, { ethers } from "hardhat";
import { rounds, totalTokenAllocation } from "../config";
import environment from "../environment";

async function main() {
  const [signer] = await ethers.getSigners();
  const dummyFactory = new DummyContract__factory(signer as unknown as Signer);

  const dummy = await dummyFactory.deploy();

  console.log(`Dummy @ ${dummy.address}`);

  await dummy.deployed();

  await new Promise((res) => setTimeout(res, 30000));

  console.log("verifying");

  await hre.run("verify:verify", {
    address: dummy.address,
  });

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
