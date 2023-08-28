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

    uint16 public immutable CHAIN_ID;
    uint16 public immutable PRESALE_CHAIN_ID;

    IStargateRouter public immutable STARGATE_ROUTER;
    uint256 public immutable STARGATE_POOL_ID;
    address public immutable STARGATE_RECEIVER;
    uint256 public immutable STARGATE_GAS;

    ISwapRouter public immutable SWAP_ROUTER;
    IWETH9 public immutable WETH;

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;

    constructor(
        uint16 chainId,
        uint16 presaleChainId,
        uint256 stargatePoolId,
        uint256 stargateGas,
        IPresale presale,
        ISwapRouter swapRouter,
        IStargateRouter stargateRouter,
        address stargateReceiver
    ) {
        CHAIN_ID = chainId;
        PRESALE_CHAIN_ID = presaleChainId;

        STARGATE_POOL_ID = stargatePoolId;
        STARGATE_ROUTER = stargateRouter;
        STARGATE_RECEIVER = CHAIN_ID == PRESALE_CHAIN_ID ? address(this) : stargateReceiver;
        STARGATE_GAS = stargateGas;

        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();
        SWAP_ROUTER = swapRouter;
        WETH = IWETH9(IPeripheryImmutableState(address(swapRouter)).WETH9());

        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
        PRESALE_ASSET.approve(address(STARGATE_ROUTER), type(uint256).max);
    }

    function sgReceive(
        uint16 srcChainId, // the remote chainId sending the tokens
        bytes memory srcAddress, // the remote Bridge address
        uint256 nonce,
        address token, // the token contract on the local chain
        uint256 amountLD, // the qty of local _token contract tokens
        bytes memory payload
    ) external override {
        require(msg.sender == address(STARGATE_ROUTER), "only stargate");

        address _account = _decodePayload(payload);
        bool _success;
        bytes memory _error;

        if (token == address(PRESALE_ASSET)) {
            try PRESALE.purchase(_account, amountLD) {
                // purchase was successful
                _success = true;
            } catch (bytes memory error) {
                // then transfer the tokens to the account directly
                _error = error;
            }
        }

        if (!_success) {
            IERC20(token).safeTransfer(_account, amountLD);
        }

        emit ReceiveStargate(srcChainId, srcAddress, nonce, token, amountLD, payload, _success, _error);
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
            bytes memory _payload = _encodePayload(account);
            uint256 _quote = quoteStargate(account);

            require(address(this).balance >= _quote, "NOT_ENOUGH_FUNDS");

            STARGATE_ROUTER.swap{value: _quote}(
                PRESALE_CHAIN_ID,
                STARGATE_POOL_ID,
                STARGATE_POOL_ID,
                payable(account),
                assetAmount,
                0, // min amount of tokens we want to receive
                IStargateRouter.lzTxObj(STARGATE_GAS, 0, abi.encodePacked(account)),
                // we can use the same address because it should be deployed to the same address
                abi.encodePacked(STARGATE_RECEIVER),
                _payload
            );
        }

        // refund any of the remaining assets
        uint256 _remainingFunds = address(this).balance;
        if (_remainingFunds > 0) {
            payable(msg.sender).sendValue(_remainingFunds);
        }
    }

    function quoteStargate(address account) public view returns (uint256 expectedFee) {
        (expectedFee,) = STARGATE_ROUTER.quoteLayerZeroFee(
            PRESALE_CHAIN_ID,
            1, // function type 1 for swap
            abi.encodePacked(STARGATE_RECEIVER),
            _encodePayload(account),
            IStargateRouter.lzTxObj(STARGATE_GAS, 0, abi.encodePacked(account))
        );
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
        return SWAP_ROUTER.exactInput{value: params.amountIn}(params);
    }

    function _deconstructPath(bytes memory path) private pure returns (address firstAddress, address lastAddress) {
        require(path.length >= 40, "lastPath_outOfBounds");

        uint256 _lastStart = path.length - 20;
        assembly {
            firstAddress := div(mload(add(add(path, 0x20), 0)), 0x1000000000000000000000000)
            lastAddress := div(mload(add(add(path, 0x20), _lastStart)), 0x1000000000000000000000000)
        }
    }

    function _encodePayload(address account) private pure returns (bytes memory) {
        return abi.encode(account);
    }

    function _decodePayload(bytes memory payload) private pure returns (address account) {
        return abi.decode(payload, (address));
    }
}
