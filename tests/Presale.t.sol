// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "testing-lib/UniswapV3Test.t.sol";
import "testing-lib/ERC20Mock.t.sol";

import "contracts/PlaceholderToken.sol";
import "contracts/Presale.sol";
import "contracts/PresaleRouter.sol";

contract PresaleTest is UniswapV3Test {
    using SafeCast for uint256;

    uint256 public constant PRECISION = 1e8;

    address public OWNER = makeAddr("OWNER");
    address public WITHDRAW_TO = makeAddr("WITHDRAW_TO");

    PlaceholderToken public presaleToken;
    ERC20Mock public presaleAsset;

    Presale public presale;
    PresaleRouter public presaleRouter;

    IPresale.PresaleConfig public presaleConfig =
        IPresale.PresaleConfig({minDepositAmount: 0, maxUserAllocation: 1e6, startDate: uint48(block.timestamp + 60)});

    IPresale.RoundConfig[] public rounds;

    constructor() {
        rounds.push(_createRoundConfig(70, 2e6));
        rounds.push(_createRoundConfig(75, 2e6));
        rounds.push(_createRoundConfig(80, 3e6));
        rounds.push(_createRoundConfig(80, 3e6));
        rounds.push(_createRoundConfig(85, 6e6));
        rounds.push(_createRoundConfig(90, 8e6));
        rounds.push(_createRoundConfig(95, 8e6));
        rounds.push(_createRoundConfig(100, 12e6));

        _createContracts();
    }

    function setUp() external {
        vm.label(address(presaleAsset), "USDT");

        vm.startPrank(OWNER);

        assertEq(presaleToken.balanceOf(OWNER), _totalTokenAllocation());
        presaleToken.approve(address(presale), type(uint256).max);
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);

        vm.stopPrank();
    }

    function test_success() external {}

    function _createContracts() internal {
        presaleToken = new PlaceholderToken(OWNER, _totalTokenAllocation());
        presaleAsset = new ERC20Mock("USDT", "USDT");
        presale = new Presale(IERC20(address(presaleAsset)), IERC20(address(presaleToken)), OWNER);
        presaleRouter = new PresaleRouter(0, 0, presale, swapRouter, IStargateRouter(address(swapRouter)));
    }

    function _fmtAsset(uint256 amount) internal pure returns (uint256) {
        return amount * (10 ** 18);
    }

    function _fmtToken(uint256 amount) internal pure returns (uint256) {
        return amount * (10 ** 8);
    }

    function _fmtPrice(uint256 price) internal pure returns (uint256) {
        return (price * _fmtAsset(1) * PRECISION) / (1000 * _fmtToken(1));
    }

    function _totalTokenAllocation() internal view returns (uint256 totalTokenAllocation) {
        for (uint256 i = 0; i < rounds.length; i++) {
            totalTokenAllocation += rounds[i].tokenAllocation;
        }
    }

    function _createRoundConfig(uint256 price, uint256 tokenAllocation)
        internal
        pure
        returns (IPresale.RoundConfig memory)
    {
        return IPresale.RoundConfig(_fmtPrice(price).toUint128(), _fmtToken(tokenAllocation).toUint128());
    }
}
