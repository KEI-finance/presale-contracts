// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/IPresaleRouter.sol";

/**
 * @notice Implementation of the {IPresale} interface.
 */
contract PresaleRouter {
    using SafeERC20 for IERC20;

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;

    constructor(IPresale presale) {
        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();

        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
    }

    function purchase(address account, uint256 amount, address referrer) external {
        uint256 currentBalance = PRESALE_ASSET.balanceOf(address(this));
        if (currentBalance < amount) {
            PRESALE_ASSET.safeTransferFrom(msg.sender, address(this), amount - currentBalance);
        }
        PRESALE.purchase(account, amount);
    }
}
