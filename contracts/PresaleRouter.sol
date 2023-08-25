// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";

import "./IPresale.sol";

/**
 * @notice Implementation of the {IPresale} interface.
 */
contract PresaleRouter {
    using Address for address payable;
    using SafeERC20 for IERC20;

    event PurchaseOutcome(
        bool success, ISwapRouter.ExactInputParams params, IPresale.Receipt receipt, address indexed sender
    );

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;
    ISwapRouter public immutable SWAP_ROUTER;
    address public immutable WETH9;

    constructor(IPresale presale, ISwapRouter swapRouter) {
        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();
        SWAP_ROUTER = swapRouter;
        WETH9 = IPeripheryImmutableState(address(swapRouter)).WETH9();

        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
    }

    function purchase(ISwapRouter.ExactInputParams memory params)
        external
        payable
        returns (bool success, IPresale.Receipt memory receipt)
    {
        (address startAsset, address endAsset) = _deconstructPath(params.path);
        require(endAsset == address(PRESALE_ASSET), "INVALID_PATH");

        IPresale.PurchaseConfig memory config;

        config.account = params.recipient;
        // we need to receive the endAsset so that we can do the presale purchase
        params.recipient = address(this);
        // by default we will assume success unless an error happens
        success = true;

        // if it is not the weth contract or there is no msg value then we must assume it is a token
        if (startAsset != WETH9 || address(this).balance == 0) {
            IERC20(startAsset).safeTransferFrom(msg.sender, address(this), params.amountIn);
            IERC20(startAsset).approve(address(SWAP_ROUTER), params.amountIn);
        }

        // attempt to swap any assets
        try SWAP_ROUTER.exactInput{value: msg.value}(params) returns (uint256 _amountOut) {
            config.amountAsset = _amountOut;
        } catch (bytes memory) {
            success = false;
        }

        if (success) {
            // then lets try and do the presale purchase
            try PRESALE.purchase(config) returns (IPresale.Receipt memory _receipt) {
                receipt = _receipt;
            } catch (bytes memory) {
                success = false;
            }

            if (!success) {
                // then lets just send them the converted asset instead
                PRESALE_ASSET.safeTransfer(config.account, config.amountAsset);
            }
        } else {
            if (address(this).balance > 0) {
                // refund to the account purchasing if the swap fails (this is to allow for cross chain)
                payable(config.account).sendValue(msg.value);
            } else {
                // refund the amount that was transferred to this contract
                IERC20(startAsset).safeTransfer(config.account, params.amountIn);
            }
        }

        emit PurchaseOutcome(success, params, receipt, msg.sender);
    }

    function _deconstructPath(bytes memory path) private pure returns (address firstAddress, address lastAddress) {
        require(path.length >= 40, "lastPath_outOfBounds");

        uint256 _lastStart = path.length - 20;
        assembly {
            firstAddress := div(mload(add(add(path, 0x20), 0)), 0x1000000000000000000000000)
            lastAddress := div(mload(add(add(path, 0x20), _lastStart)), 0x1000000000000000000000000)
        }
    }
}
