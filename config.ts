import { IPresale } from "./typechain-types";
import { BigNumber } from "ethers";

export const config: IPresale.PresaleConfigStruct = {
  minDepositAmount: 0,
  maxUserAllocation: BigNumber.from(10).pow(14),
  startDate: Math.round(Date.parse("2023-08-29T14:00:00.000Z") / 1000),
};

const EXTRA_TOKEN_ALLOCATION = makeTokens(6e6);

export const makeRounds = (
  decimals: number
): {
  rounds: IPresale.RoundConfigStruct[];
  totalTokenAllocation: BigNumber;
} => {
  const rounds = [
    {
      price: makePrice(0.07),
      allocation: makeTokens(2e6),
    },
    {
      price: makePrice(0.075),
      allocation: makeTokens(2e6),
    },
    {
      price: makePrice(0.08),
      allocation: makeTokens(3e6),
    },
    {
      price: makePrice(0.085),
      allocation: makeTokens(6e6),
    },
    {
      price: makePrice(0.09),
      allocation: makeTokens(8e6),
    },
    {
      price: makePrice(0.095),
      allocation: makeTokens(8e6),
    },
    {
      price: makePrice(0.1),
      allocation: makeTokens(12e6),
    },
  ];
  const totalTokenAllocation = rounds
    .reduce(
      (total, current) => total.add(current.allocation),
      BigNumber.from(0)
    )
    .add(EXTRA_TOKEN_ALLOCATION);

  return { rounds, totalTokenAllocation };

  function makePrice(price: number) {
    return BigNumber.from(Math.round(price * 1e3)).mul(
      BigNumber.from(10).pow(decimals - 3)
    );
  }
};

function makeTokens(amount: number) {
  return BigNumber.from(10).pow(8).mul(amount);
}
