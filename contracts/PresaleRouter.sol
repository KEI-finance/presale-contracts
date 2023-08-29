// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "stargate/IStargateReceiver.sol";

import "./interfaces/IPresaleRouter.sol";

/**
 * @notice Implementation of the {IPresaleRouter} interface.
 */
contract PresaleRouter is IPresaleRouter, IStargateReceiver {
    using SafeERC20 for IERC20;

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;

    constructor(IPresale presale) {
        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();
        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
    }

    function sgReceive(
        uint16 srcChainId, // the remote chainId sending the tokens
        bytes memory srcAddress, // the remote Bridge address
        uint256 nonce,
        address token, // the token contract on the local chain
        uint256 amountLD, // the qty of local _token contract tokens
        bytes memory payload
    ) external override {
        emit ReceiveStargate(srcChainId, srcAddress, nonce, token, amountLD, payload);
        PurchaseParams memory _params = abi.decode(payload, (PurchaseParams));
        purchase(_params);
    }

    function purchase(PurchaseParams memory params) public override {
        uint256 _currentBalance = PRESALE_ASSET.balanceOf(address(this));
        if (_currentBalance < params.assetAmount) {
            PRESALE_ASSET.safeTransferFrom(msg.sender, address(this), params.assetAmount - _currentBalance);
        }

        bool _success;
        IPresale.Receipt memory _receipt;
        try PRESALE.purchase(params.account, params.assetAmount) returns (IPresale.Receipt memory receipt) {
            _success = true;
            _receipt = receipt;
        } catch {
            // in the event the purchase failed then send the assets to the account
            PRESALE_ASSET.safeTransfer(params.account, params.assetAmount);
        }

        emit PurchaseResult(params, _success, _receipt, msg.sender);
    }
}
