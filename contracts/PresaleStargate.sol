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
import "./interfaces/IPresaleStargate.sol";

/**
 * @notice Implementation of the {IPresale} interface.
 */
contract PresaleStargate is IPresaleStargate {
    using Address for address payable;
    using Address for address;
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    uint16 public immutable PRESALE_CHAIN_ID;

    IStargateRouter public immutable STARGATE_ROUTER;
    uint256 public immutable STARGATE_POOL_ID;
    uint256 public immutable STARGATE_GAS;

    IPresaleRouter public immutable PRESALE_ROUTER;
    IERC20 public immutable PRESALE_ASSET;
    ISwapRouter public immutable SWAP_ROUTER;
    IWETH9 public immutable WETH;

    constructor(
        uint16 presaleChainId,
        uint256 stargatePoolId,
        uint256 stargateGas,
        IERC20 presaleAsset,
        ISwapRouter swapRouter,
        IPresaleRouter presaleRouter,
        IStargateRouter stargateRouter
    ) {
        PRESALE_CHAIN_ID = presaleChainId;

        STARGATE_POOL_ID = stargatePoolId;
        STARGATE_ROUTER = stargateRouter;
        STARGATE_GAS = stargateGas;

        SWAP_ROUTER = swapRouter;
        PRESALE_ROUTER = presaleRouter;
        PRESALE_ASSET = presaleAsset;
        WETH = IWETH9(IPeripheryImmutableState(address(swapRouter)).WETH9());

        PRESALE_ASSET.approve(address(STARGATE_ROUTER), type(uint256).max);
    }

    function swapAndPurchaseExactInput(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactInputParams calldata swapParams
    ) external payable override {
        _receivePresaleAsset(purchaseParams.assetAmount);
        SWAP_ROUTER.exactInput(swapParams);
        _sendStargate(purchaseParams);
    }

    function swapAndPurchaseExactOutput(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactOutputParams calldata swapParams
    ) external payable override {
        _receivePresaleAsset(purchaseParams.assetAmount);
        SWAP_ROUTER.exactOutput(swapParams);
        _sendStargate(purchaseParams);
    }

    function swapAndPurchaseExactInputETH(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactInputParams calldata swapParams
    ) external payable override {
        // assume the swap will provide the presale asset
        SWAP_ROUTER.exactInput{value: swapParams.amountIn}(swapParams);
        _withdrawWETH();
        _sendStargate(purchaseParams);
    }

    function swapAndPurchaseExactOutputETH(
        IPresaleRouter.PurchaseParams calldata purchaseParams,
        ISwapRouter.ExactOutputParams calldata swapParams
    ) external payable override {
        // assume the swap will provide the presale asset
        SWAP_ROUTER.exactOutput{value: swapParams.amountInMaximum}(swapParams);
        _withdrawWETH();
        _sendStargate(purchaseParams);
    }

    function purchase(IPresaleRouter.PurchaseParams calldata params) public payable override {
        _receivePresaleAsset(params.assetAmount);
        _sendStargate(params);
    }

    function quote(IPresaleRouter.PurchaseParams memory params) public view returns (uint256 expectedFee) {
        (expectedFee,) = STARGATE_ROUTER.quoteLayerZeroFee(
            PRESALE_CHAIN_ID,
            1, // function type 1 for swap
            abi.encodePacked(address(PRESALE_ROUTER)),
            abi.encode(params),
            IStargateRouter.lzTxObj(STARGATE_GAS, 0, abi.encodePacked(params.account))
        );
    }

    function _receivePresaleAsset(uint256 assetAmount) private {
        PRESALE_ASSET.transferFrom(msg.sender, address(this), assetAmount);
    }

    function _withdrawWETH() private {
        uint256 _wethBalance = WETH.balanceOf(address(this));
        if (_wethBalance > 0) WETH.withdraw(_wethBalance);
    }

    function _sendStargate(IPresaleRouter.PurchaseParams calldata params) private {
        uint256 _assetAmount = PRESALE_ASSET.balanceOf(address(this));
        uint256 _value = address(this).balance;

        STARGATE_ROUTER.swap{value: _value}(
            PRESALE_CHAIN_ID,
            STARGATE_POOL_ID,
            STARGATE_POOL_ID,
            payable(params.account),
            _assetAmount,
            0, // min amount of tokens we want to receive
            IStargateRouter.lzTxObj(STARGATE_GAS, 0, abi.encodePacked(params.account)),
            // we can use the same address because it should be deployed to the same address
            abi.encodePacked(address(PRESALE_ROUTER)),
            abi.encode(params)
        );

        emit SendStargate(params, _assetAmount, _value, msg.sender);
    }
}
