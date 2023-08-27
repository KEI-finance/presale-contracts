import hre from "hardhat";
import path from "path";

let environment = {
  swapRouter: "",
  presaleAsset: "",
  withdrawTo: "",
  owner: "",
};

try {
  ({ environment } = require(path.join(__dirname, hre.network.name + ".ts")));
} catch (e) {
  console.log("unknown environment " + hre.network.name);
}

export default environment;
