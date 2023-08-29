import hre from "hardhat";
import path from "path";

let environment = {
  stargate: {
    swapRouter: "",
    presaleAsset: "",
    presaleRouter: "",
    stargateRouter: "",
    presaleChainId: 0,
    stargatePoolId: 0,
    stargateGas: 500_000,
  },
  presale: {
    presaleAsset: "",
    withdrawTo: "",
    owner: "",
  },
};

try {
  const { environment: newEnvironment } = require(path.join(
    __dirname,
    hre.network.name + ".ts"
  ));

  environment = {
    ...environment,
    ...newEnvironment,
    stargate: {
      ...environment.stargate,
      ...newEnvironment.stargate,
    },
    presale: {
      ...environment.presale,
      ...newEnvironment.presale,
    },
  };
} catch (e) {
  console.log("unknown environment " + hre.network.name);
}

export default environment;
