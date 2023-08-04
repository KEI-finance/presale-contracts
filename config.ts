import { IPresale } from "./typechain-types";
import { BigNumber } from "ethers";

export const rounds: IPresale.RoundConfigStruct[] = [
  {
    tokenPrice: makePrice(0.07),
    tokensAllocated: makeTokens(2e6),
  },
  {
    tokenPrice: makePrice(0.075),
    tokensAllocated: makeTokens(2e6),
  },
  {
    tokenPrice: makePrice(0.08),
    tokensAllocated: makeTokens(3e6),
  },
  {
    tokenPrice: makePrice(0.085),
    tokensAllocated: makeTokens(6e6),
  },
  {
    tokenPrice: makePrice(0.09),
    tokensAllocated: makeTokens(8e6),
  },
  {
    tokenPrice: makePrice(0.095),
    tokensAllocated: makeTokens(8e6),
  },
  {
    tokenPrice: makePrice(0.1),
    tokensAllocated: makeTokens(6e6),
  },
];

function makePrice(price: number) {
  return BigNumber.from(Math.round(price * 1e3)).mul(
    BigNumber.from(10).pow(15)
  );
}

function makeTokens(amount: number) {
  return BigNumber.from(10).pow(8).mul(amount);
}
