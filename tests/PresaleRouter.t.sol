// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "testing-lib/UniswapV3Test.t.sol";
import "testing-lib/ERC20Mock.t.sol";

import "contracts/PresaleRouter.sol";

import "./Presale.t.sol";

contract PresaleRouterTest is UniswapV3Test, PresaleTest {
    function test_gas() external {
        presaleConfig.maxUserAllocation = type(uint256).max;
        setUp();

        vm.warp(presaleConfig.startDate);

        PresaleRouter router =
            new PresaleRouter(0, 0, 1, 500_000, presale, swapRouter, IStargateRouter(address(this)), address(this));

        uint256 totalAssets = _remainingAssetAllocation();
        presaleAsset.mint(address(this), totalAssets);
        presaleAsset.transfer(address(router), totalAssets);

        uint256 gasLeft = gasleft();
        router.sgReceive(0, abi.encodePacked(address(this)), 0, address(presaleAsset), totalAssets, abi.encode(ALICE));
        assertLt(gasLeft - gasleft(), 500_000); // less than 500k gas allowed

        assertGt(presale.totalRaised(), 0);
    }
}
