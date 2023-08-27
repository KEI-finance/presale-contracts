import {
  ERC20__factory,
  IERC20__factory,
  IStargateRouter__factory,
} from "../typechain-types";
import hre, { ethers } from "hardhat";
import { constants } from "ethers";
import { parseUnits } from "ethers/lib/utils";

async function main() {
  const [signer] = await ethers.getSigners();

  const DUMMY_GOERLI = "0x78682e73425DeD76caFe1c46Fb332509e6fb1995";
  const DUMMY_ARB_GOERLI = "0xa9d0196081fEe45A8c82577Dae2ef428D928264e";
  const DUMMY_BSC_TESTNET = "0x2AaaA921C551AA5A66aE5a8cbf42e6A24Ba22Bfd";
  const GOERLI_CHAIN_ID = 10121;
  const ARB_GOERLI_CHAIN_ID = 10143;
  const BSC_TESTNET_CHAIN_ID = 10102;
  const USDC_GOERLI = "0xDf0360Ad8C5ccf25095Aa97ee5F2785c8d848620";
  const USDC_ARB_GOERLI = "0x6aAd876244E7A1Ad44Ec4824Ce813729E5B6C291";
  const stargate = IStargateRouter__factory.connect(
    "0x7612aE2a34E5A363E137De748801FB4c86499152",
    signer
  );
  const usdc = IERC20__factory.connect(USDC_GOERLI, signer);
  const payload = "0x";
  // const payload = usdc.interface.encodeFunctionData("transfer", [
  //   constants.AddressZero,
  //   "1000000",
  // ]);

  console.log(payload);
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
    dstGasForCall: 800_000, // extra gas, if calling smart contract,
    dstNativeAmount: parseUnits("0.01", "ether"), // amount of dust dropped in destination wallet
    dstNativeAddr: "0x921d360aD22A6D0289ce57fcb8250e299cB19EA3", // destination wallet for dust
  };

  const quoteData = await stargate.quoteLayerZeroFee(
    BSC_TESTNET_CHAIN_ID, // destination chainId
    1, // function type: see Bridge.sol for all types
    DUMMY_BSC_TESTNET, // destination of tokens
    payload, // payload, using abi.encode()
    call
  );

  console.log(quoteData);

  const tx = await stargate.swap(
    BSC_TESTNET_CHAIN_ID, // destination chainId
    1, // source poolId
    2, // destination poolId
    DUMMY_BSC_TESTNET, // refund address. extra gas (if any) is returned to this address
    100000000, // quantity to swap in LD (local decimals)
    0, // the min qty you would accept in LD (local decimals)
    call,
    DUMMY_BSC_TESTNET, // the address to send the tokens to on the destination
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
