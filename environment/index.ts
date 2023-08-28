import hre from "hardhat";
import path from "path";
import { constants } from "ethers";

let environment = {
  presaleAsset: constants.AddressZero,
  withdrawTo: constants.AddressZero,
  owner: constants.AddressZero,
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
