// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "stargate/IStargateReceiver.sol";

import "./interfaces/IPresaleRouter.sol";

/**
 * @notice Implementation of the {IPresaleRouter} interface.
 */
contract PresaleRouter is IStargateReceiver {
    using SafeERC20 for IERC20;

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;

    constructor(IPresale presale) {
        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();
        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
    }

    function sgReceive(
        uint16 srcChainId,              // the remote chainId sending the tokens
        bytes memory srcAddress,        // the remote Bridge address
        uint256 nonce,
        address token,                  // the token contract on the local chain
        uint256 amountLD,                // the qty of local _token contract tokens
        bytes memory payload
    ) external {
        (address account, address referrer) = abi.decode(payload, (address, address));
        purchase(account, amountLD, referrer);
    }

    function purchase(address account, uint256 amount, address referrer) public {
        uint256 currentBalance = PRESALE_ASSET.balanceOf(address(this));
        if (currentBalance < amount) {
            PRESALE_ASSET.safeTransferFrom(msg.sender, address(this), amount - currentBalance);
        }
        try PRESALE.purchase(account, amount) {
            return;
        } catch {
            PRESALE_ASSET.safeTransfer(account, amount);
        }
    }
}
