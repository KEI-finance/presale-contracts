import "dotenv/config";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import "@nomiclabs/hardhat-ethers";
import "hardhat-package";

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  networks: {
    goerli: {
      url: "https://goerli.infura.io/v3/" + process.env.INFURA_API_KEY,
      chainId: 5,
      accounts: [process.env.GOERLI_TESTNET_PRIVATE_KEY!],
    },
    arbitrumGoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      chainId: 421613,
      accounts: [process.env.GOERLI_TESTNET_PRIVATE_KEY!],
    },
    arbitrumOne: {
      url: "https://arb1.arbitrum.io/rpc",
      accounts: [process.env.ARBITRUM_MAINNET_PRIVATE_KEY!],
    },
    bscTestnet: {
      url: "https://data-seed-prebsc-1-s3.binance.org:8545/",
      accounts: [process.env.GOERLI_TESTNET_PRIVATE_KEY!],
    },
    polygonMumbai: {
      url: "https://rpc-mumbai.maticvigil.com",
      accounts: [process.env.GOERLI_TESTNET_PRIVATE_KEY!],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY!,
      goerli: process.env.ETHERSCAN_API_KEY!,
      arbitrumGoerli: process.env.ARB_ETHERSCAN_API_KEY!,
      arbitrumOne: process.env.ARB_ETHERSCAN_API_KEY!,
      bscTestnet: process.env.BSC_ETHERSCAN_API_KEY!,
      polygonMumbai: process.env.POLYGON_ETHERSCAN_API_KEY!,
    },
  },
  package: {
    copy: [{ src: "./deployments.ts", dest: "./deployments.ts" }],
  },
};

export default config;
