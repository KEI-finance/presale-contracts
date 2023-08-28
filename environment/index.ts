import hre from "hardhat";
import path from "path";

let environment = {
  stargateRouter: "",
  stargateReceiver: "",
  presaleAsset: "",
  swapRouter: "",
  withdrawTo: "",
  presale: "",
  owner: "",
  stargateGas: 500_000,
  stargatePoolId: 2,
  chainId: 0,
  presaleChainId: 0,
};

try {
  environment = {
    ...environment,
    ...require(path.join(__dirname, hre.network.name + ".ts")),
  };
} catch (e) {
  console.log("unknown environment " + hre.network.name);
}

export default environment;
