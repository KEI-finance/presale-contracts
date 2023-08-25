// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract PlaceholderToken is ERC20Burnable {
    constructor(address receiver, uint256 totalSupply) ERC20("KEI Placeholder Token", "KPT") {
        _mint(receiver, totalSupply);
    }
}
