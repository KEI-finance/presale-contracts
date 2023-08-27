// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol";

import "stargate/IStargateRouter.sol";
import "stargate/IStargateReceiver.sol";

import "./interfaces/external/IWETH9.sol";
import "./interfaces/IPresale.sol";
import "./interfaces/IPresaleRouter.sol";

/**
 * @notice Implementation of the {IPresale} interface.
 */
contract PresaleRouter is IPresaleRouter, IStargateReceiver {
    using Address for address payable;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    uint256 public immutable STARGATE_POOL_ID;

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;
    ISwapRouter public immutable SWAP_ROUTER;
    IStargateRouter public immutable STARGATE_ROUTER;
    IWETH9 public immutable WETH;

    uint16 public immutable CHAIN_ID;
    uint16 public immutable PRESALE_CHAIN_ID;

    constructor(
        uint16 chainId,
        uint16 presaleChainId,
        uint256 stargatePoolId,
        IPresale presale,
        ISwapRouter swapRouter,
        IStargateRouter stargateRouter
    ) {
        CHAIN_ID = chainId;
        PRESALE_CHAIN_ID = presaleChainId;
        STARGATE_POOL_ID = stargatePoolId;

        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();
        SWAP_ROUTER = swapRouter;
        STARGATE_ROUTER = stargateRouter;
        WETH = IWETH9(IPeripheryImmutableState(address(swapRouter)).WETH9());

        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
        PRESALE_ASSET.approve(address(STARGATE_ROUTER), type(uint256).max);
    }

    function sgReceive(
        uint16 srcChainId,              // the remote chainId sending the tokens
        bytes memory srcAddress,        // the remote Bridge address
        uint256 nonce,
        address token,                  // the token contract on the local chain
        uint256 amountLD,                // the qty of local _token contract tokens
        bytes memory payload
    ) external override {
        address account = abi.decode(payload, (address));

        if (token == address(PRESALE_ASSET)) {
            try PRESALE.purchase(account, amountLD) {
                return;
            } catch {
                // then transfer the tokens to the account directly
            }
        }

        IERC20(token).safeTransfer(account, amountLD);
    }

    function purchase(ISwapRouter.ExactInputParams memory params) external payable {
        address account = params.recipient;
        uint128 assetAmount;

        // if there is no path we can assume that they are using the token directly
        if (params.path.length > 0) {
            // we need to receive the endAsset so that we can do the presale purchase
            params.recipient = address(this);
            assetAmount = _swap(params).toUint128();
        } else {
            // we need to transfer to this contract so we can purchase
            PRESALE_ASSET.safeTransferFrom(msg.sender, address(this), params.amountIn);
            assetAmount = params.amountIn.toUint128();
        }

        if (CHAIN_ID == PRESALE_CHAIN_ID) {
            PRESALE.purchase(account, assetAmount);
        } else {
            bytes memory receiver = abi.encodePacked(address(this));
            STARGATE_ROUTER.swap(
                PRESALE_CHAIN_ID,
                STARGATE_POOL_ID,
                STARGATE_POOL_ID,
                payable(account),
                assetAmount,
                0, // min amount of tokens we want to receive
                IStargateRouter.lzTxObj(0, 0, receiver),
                // we can use the same address because it should be deployed to the same address
                receiver,
                abi.encode(account)
            );
        }
    }

    function _swap(ISwapRouter.ExactInputParams memory params) private returns (uint256 amountOut) {
        (address startAsset, address endAsset) = _deconstructPath(params.path);
        require(endAsset == address(PRESALE_ASSET), "INVALID_SWAP_PATH");

        // if it is not the weth contract or there is no msg value then we must assume it is a token
        if (startAsset != address(WETH) || address(this).balance == 0) {
            IERC20(startAsset).safeTransferFrom(msg.sender, address(this), params.amountIn);
            IERC20(startAsset).approve(address(SWAP_ROUTER), params.amountIn);
        }

        // attempt to swap any assets
        return SWAP_ROUTER.exactInput{value: address(this).balance}(params);
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
