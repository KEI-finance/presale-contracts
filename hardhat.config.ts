import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import * as process from "process";

require("dotenv").config();

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  // networks: {
  //   hardhat: {
  //     chainId: 1337,
  //   },
  //   arbitrumGoerli: {
  //     url: "https://goerli-rollup.arbitrum.io/rpc",
  //     chainId: 421613,
  //     accounts: [process.env.GOERLI_TESTNET_PRIVATE_KEY!],
  //   },
  //   arbitrumOne: {
  //     url: "https://arb1.arbitrum.io/rpc",
  //     accounts: [process.env.ARBITRUM_MAINNET_PRIVATE_KEY!],
  //   },
  // },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
