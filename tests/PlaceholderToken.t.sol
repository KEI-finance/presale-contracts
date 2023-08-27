// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "testing-lib/BaseTest.t.sol";
import "contracts/PlaceholderToken.sol";

contract PlaceholderTokenTest is BaseTest {

    function test(address recipient, uint256 totalSupply) external {
        vm.assume(recipient != address(0) && totalSupply > 0);

        PlaceholderToken token = new PlaceholderToken(recipient, totalSupply);

        assertEq(token.balanceOf(recipient), totalSupply);
        assertEq(token.decimals(), 8);
    }
}
