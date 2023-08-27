import hre from "hardhat";
import path from "path";

let environment = {
  stargateRouter: "",
  presaleAsset: "",
  swapRouter: "",
  withdrawTo: "",
  presale: "",
  owner: "",
  stargatePoolId: 0,
  chainId: 0,
  presaleChainId: 0,
};

try {
  ({ environment } = require(path.join(__dirname, hre.network.name + ".ts")));
} catch (e) {
  console.log("unknown environment " + hre.network.name);
}

export default environment;
