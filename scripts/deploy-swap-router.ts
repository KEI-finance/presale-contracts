import swapRouterJson from "@uniswap/v3-periphery/artifacts/contracts/SwapRouter.sol/SwapRouter.json";
import { ContractFactory, Signer } from "ethers";
import env, { ethers } from "hardhat";
import environment from "../environment";

async function main() {
  const [signer] = await ethers.getSigners();
  const swapRouterFactory = ContractFactory.fromSolidity(
    swapRouterJson,
    signer as unknown as Signer
  );

  const swapRouter = await swapRouterFactory.deploy(
    "0x4893376342d5d7b3e31d4184c08b265e5ab2a3f6",
    "0xe39Ab88f8A4777030A534146A9Ca3B52bd5D43A3"
  );

  console.log(`SwapRouter @ ${swapRouter.address}`);

  await swapRouter.deployed();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
