import hre from "hardhat";
import path from "path";
import { constants } from "ethers";

let environment = {
  stargateReceiver: constants.AddressZero,
  stargateRouter: constants.AddressZero,
  presaleAsset: constants.AddressZero,
  swapRouter: constants.AddressZero,
  withdrawTo: constants.AddressZero,
  presale: constants.AddressZero,
  owner: constants.AddressZero,
  stargateGas: 500_000,
  stargatePoolId: 2,
  chainId: 0,
  presaleChainId: 0,
};

try {
  environment = {
    ...environment,
    ...require(path.join(__dirname, hre.network.name + ".ts")).environment,
  };
} catch (e) {
  console.log("unknown environment " + hre.network.name);
}

export default environment;
