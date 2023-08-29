import hre from "hardhat";
import path from "path";

let environment = {
  referrals: "",
  presaleAsset: "",
  withdrawTo: "",
  owner: "",
};

try {
  const { environment: newEnvironment } = require(path.join(
    __dirname,
    hre.network.name + ".ts"
  ));

  environment = {
    ...environment,
    ...newEnvironment,
  };
} catch (e) {
  console.log("unknown environment " + hre.network.name);
}

export default environment;
