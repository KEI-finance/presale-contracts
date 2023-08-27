// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title KEI Finance Presale Contract.
 * @author KEI Finance
 * @notice A fund raising contract for initial token offering.
 */
interface IPresaleRouter {
    function purchase(ISwapRouter.ExactInputParams memory params) external payable;
}
