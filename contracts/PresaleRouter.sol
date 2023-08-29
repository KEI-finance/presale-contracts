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

    function sgReceive(uint16, bytes memory, uint256, address, uint256 assetAmount, bytes memory payload)
        external
        override
    {
        PurchaseParams memory params = abi.decode(payload, (PurchaseParams));
        purchase(params);
    }

    function purchase(PurchaseParams memory params) public override {
        uint256 currentBalance = PRESALE_ASSET.balanceOf(address(this));
        if (currentBalance < params.assetAmount) {
            PRESALE_ASSET.safeTransferFrom(msg.sender, address(this), params.assetAmount - currentBalance);
        }

        try PRESALE.purchase(params.account, params.assetAmount) {
            return;
        } catch {
            // in the event the purchase failed then send the assets to the account
            PRESALE_ASSET.safeTransfer(params.account, params.assetAmount);
        }
    }
}
