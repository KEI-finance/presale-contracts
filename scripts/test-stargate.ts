import { IERC20__factory, IStargateRouter__factory } from "../typechain-types";
import hre, { ethers } from "hardhat";
import { BigNumber, constants } from "ethers";

async function main() {
  const [signer] = await ethers.getSigners();

  const DUMMY_GOERLI = "0x78682e73425DeD76caFe1c46Fb332509e6fb1995";
  const DUMMY_ARB_GOERLI = "0xa9d0196081fEe45A8c82577Dae2ef428D928264e";
  const GOERLI_CHAIN_ID = 10121;
  const ARB_GOERLI_CHAIN_ID = 10143;
  const USDC_GOERLI = "0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620";
  const USDC_ARB_GOERLI = "0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291";
  const stargate = IStargateRouter__factory.connect(
    "0x7612aE2a34E5A363E137De748801FB4c86499152",
    signer
  );
  const payload = "0x";

  const usdc = IERC20__factory.connect(USDC_GOERLI, signer);

  // if (
  //   await usdc
  //     .allowance(signer.address, stargate.address)
  //     .then((allowance) => allowance !== constants.MaxUint256.toBigInt())
  // ) {
  //   await usdc
  //     .approve(stargate.address, constants.MaxUint256)
  //     .then((tx) => tx.wait());
  //   console.log("approved");
  // }

  const call = {
    dstGasForCall: 500_000, // extra gas, if calling smart contract,
    dstNativeAmount: 0, // amount of dust dropped in destination wallet
    dstNativeAddr: "0x", // destination wallet for dust
  };

  const quoteData = await stargate.quoteLayerZeroFee(
    ARB_GOERLI_CHAIN_ID, // destination chainId
    1, // function type: see Bridge.sol for all types
    DUMMY_ARB_GOERLI, // destination of tokens
    payload, // payload, using abi.encode()
    call
  );

  console.log(quoteData);

  const tx = await stargate.swap(
    ARB_GOERLI_CHAIN_ID, // destination chainId
    1, // source poolId
    1, // destination poolId
    DUMMY_ARB_GOERLI, // refund address. extra gas (if any) is returned to this address
    10000000, // quantity to swap in LD (local decimals)
    0, // the min qty you would accept in LD (local decimals)
    call,
    DUMMY_ARB_GOERLI, // the address to send the tokens to on the destination
    payload, // payload
    { value: quoteData[0] } // "fee" is the native gas to pay for the cross chain message fee. see
  );

  console.log(tx.hash);

  await tx.wait();

  console.log("completed");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
