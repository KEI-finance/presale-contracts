// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";

import "stargate/IStargateRouter.sol";

import "./IPresale.sol";

/**
 * @notice Implementation of the {IPresale} interface.
 */
contract PresaleRouter {
    using Address for address payable;
    using SafeERC20 for IERC20;

    uint256 public constant STARGATE_USDT_POOL_ID = 2;

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;
    ISwapRouter public immutable SWAP_ROUTER;
    IStargateRouter public immutable STARGATE_ROUTER;

    address public immutable WETH9;
    uint16 public immutable CHAIN_ID;
    uint16 public immutable PRESALE_CHAIN_ID;

    constructor(
        uint16 chainId,
        uint16 presaleChainId,
        IPresale presale,
        ISwapRouter swapRouter,
        IStargateRouter stargateRouter
    ) {
        CHAIN_ID = chainId;
        PRESALE_CHAIN_ID = presaleChainId;

        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();
        SWAP_ROUTER = swapRouter;
        STARGATE_ROUTER = stargateRouter;
        WETH9 = IPeripheryImmutableState(address(swapRouter)).WETH9();

        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
        PRESALE_ASSET.approve(address(STARGATE_ROUTER), type(uint256).max);
    }

    function purchase(ISwapRouter.ExactInputParams memory params) external payable {
        IPresale.PurchaseConfig memory config;
        config.account = params.recipient;

        // if there is no path we can assume that they are using the token directly
        if (params.path.length > 0) {
            // we need to receive the endAsset so that we can do the presale purchase
            params.recipient = address(this);
            config.amountAsset = _swap(params);
        } else {
            // we need to transfer to this contract so we can purchase
            PRESALE_ASSET.safeTransferFrom(msg.sender, address(this), params.amountIn);
            config.amountAsset = params.amountIn;
        }

        if (CHAIN_ID == PRESALE_CHAIN_ID) {
            PRESALE.purchase(config);
        } else {
            STARGATE_ROUTER.swap(
                PRESALE_CHAIN_ID,
                STARGATE_USDT_POOL_ID,
                STARGATE_USDT_POOL_ID,
                payable(config.account),
                config.amountAsset,
                config.amountAsset,
                IStargateRouter.lzTxObj(0, 0, "0x"),
                abi.encodePacked(PRESALE),
                abi.encodeWithSelector(IPresale.purchase.selector, config)
            );
        }
    }

    function _swap(ISwapRouter.ExactInputParams memory params) private returns (uint256 amountOut) {
        (address startAsset, address endAsset) = _deconstructPath(params.path);
        require(endAsset == address(PRESALE_ASSET), "INVALID_SWAP_PATH");

        // if it is not the weth contract or there is no msg value then we must assume it is a token
        if (startAsset != WETH9 || address(this).balance == 0) {
            IERC20(startAsset).safeTransferFrom(msg.sender, address(this), params.amountIn);
            IERC20(startAsset).approve(address(SWAP_ROUTER), params.amountIn);
        }

        // attempt to swap any assets
        return SWAP_ROUTER.exactInput{value: msg.value}(params);
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
