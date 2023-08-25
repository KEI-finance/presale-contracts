import { IPresale } from "./typechain-types";
import { BigNumber } from "ethers";

export const rounds: IPresale.RoundConfigStruct[] = [
  {
    tokenPrice: makePrice(0.07),
    tokenAllocation: makeTokens(2e6),
  },
  {
    tokenPrice: makePrice(0.075),
    tokenAllocation: makeTokens(2e6),
  },
  {
    tokenPrice: makePrice(0.08),
    tokenAllocation: makeTokens(3e6),
  },
  {
    tokenPrice: makePrice(0.085),
    tokenAllocation: makeTokens(6e6),
  },
  {
    tokenPrice: makePrice(0.09),
    tokenAllocation: makeTokens(8e6),
  },
  {
    tokenPrice: makePrice(0.095),
    tokenAllocation: makeTokens(8e6),
  },
  {
    tokenPrice: makePrice(0.1),
    tokenAllocation: makeTokens(12e6),
  },
];

export const totalTokenAllocation = rounds.reduce((total, current) => (total.add(current.tokenAllocation)), BigNumber.from(0));

function makePrice(price: number) {
  return BigNumber.from(Math.round(price * 1e3)).mul(
    BigNumber.from(10).pow(15)
  );
}

function makeTokens(amount: number) {
  return BigNumber.from(10).pow(8).mul(amount);
}
