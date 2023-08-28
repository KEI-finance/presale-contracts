// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

import "./IPresale.sol";

/**
 * @title KEI Finance Presale Contract.
 * @author KEI Finance
 * @notice A fund raising contract for initial token offering.
 */
interface IPresaleRouter {
    event SendStargate();

    // the remote chainId sending the tokens
    // the remote Bridge address
    // the token contract on the local chain
    // the qty of local _token contract tokens
    event ReceiveStargate(
        uint16 srcChainId,
        bytes srcAddress,
        uint256 nonce,
        address token,
        uint256 amountLD,
        bytes payload,
        bool success,
        bytes error
    );

    function purchase(ISwapRouter.ExactInputParams memory params) external payable;
}
