import { Presale__factory } from "../typechain-types";
import { BigNumber, Signer } from "ethers";
import { ethers } from "hardhat";
import { rounds } from "../config";

async function main() {
  const [signer] = await ethers.getSigners();
  const presaleFactory = new Presale__factory(signer as unknown as Signer);

  // goerli configuration
  const presale = await presaleFactory.deploy(
    "0x48731cF7e84dc94C5f84577882c14Be11a5B7456",
    "0x3829018f5c984b2b7cf8382704da7329d4c27da4",
    "0x73967c6a0904aA032C103b4104747E88c566B1A2",
    {
      minDepositAmount: 0,
      maxUserAllocation: BigNumber.from(10).pow(14),
      endDate: Math.round(new Date("11/01/2023").getTime() / 1000),
      startDate: Math.round(Date.now() / 1000),
      withdrawTo: "0x921d360aD22A6D0289ce57fcb8250e299cB19EA3",
    },
    rounds
  );

  console.log(`Deployed to ${presale.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
