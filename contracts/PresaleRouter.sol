// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IPresaleRouter.sol";

/**
 * @notice Implementation of the {IPresale} interface.
 */
contract PresaleRouter {

    IPresale public immutable PRESALE;
    IERC20 public immutable PRESALE_ASSET;

    constructor(IPresale presale) {
        PRESALE = presale;
        PRESALE_ASSET = presale.PRESALE_ASSET();

        PRESALE_ASSET.approve(address(PRESALE), type(uint256).max);
    }

    function purchase(address account) external {
        PRESALE.purchase(account, PRESALE_ASSET.balanceOf(address(this)));
    }
}
