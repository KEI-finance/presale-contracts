// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "./IPresaleRouter.sol";

interface IPresaleStargate {
    event SendStargate(
        IPresaleRouter.PurchaseParams purchaseParams, uint256 assetAmount, uint256 value, address indexed sender
    );

    function swapAndPurchaseExactInput(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactInputParams calldata swapParams
    ) external payable;

    function swapAndPurchaseExactOutput(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactOutputParams calldata swapParams
    ) external payable;

    function swapAndPurchaseExactInputETH(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactInputParams calldata swapParams
    ) external payable;

    function swapAndPurchaseExactOutputETH(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactOutputParams calldata swapParams
    ) external payable;

    function purchase(IPresaleRouter.PurchaseParams calldata params) external payable;

    function quote(IPresaleRouter.PurchaseParams memory params) external view returns (uint256 expectedFee);
}
