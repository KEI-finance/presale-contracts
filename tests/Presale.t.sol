// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "testing-lib/UniswapV3Test.t.sol";
import "testing-lib/ERC20Mock.t.sol";

import "contracts/PlaceholderToken.sol";
import "contracts/Presale.sol";
import "contracts/PresaleRouter.sol";

contract PresaleTest is UniswapV3Test, IPresaleErrors {
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

    function setUp() public virtual {
        vm.label(address(presaleAsset), "USDT");

        vm.prank(OWNER);
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);
    }

    function test_construct() external {}

    function _createContracts() internal {
        presaleToken = new PlaceholderToken(OWNER, _totalTokenAllocation());
        presaleAsset = new ERC20Mock("USDT", "USDT");
        presale = new Presale(IERC20(address(presaleAsset)), IERC20(address(presaleToken)), OWNER);
        presaleRouter = new PresaleRouter(0, 0, presale, swapRouter, IStargateRouter(address(swapRouter)));

        vm.prank(OWNER);
        presaleToken.approve(address(presale), type(uint256).max);
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
            totalTokenAllocation += rounds[i].allocation;
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

contract PresaleTest__initialize is PresaleTest {
    using SafeCast for uint256;

    function setUp() public virtual override {
        // cancel initialization
    }

    function test_success() external {
        assertEq(presale.totalRounds(), 0);
        assertNotEq0(abi.encode(presale.config()), abi.encode(presaleConfig));
        assertNotEq0(abi.encode(presale.rounds()), abi.encode(rounds));

        vm.prank(OWNER);
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);

        assertEq(presale.totalRounds(), rounds.length);
        assertEq0(abi.encode(presale.config()), abi.encode(presaleConfig));
        assertEq0(abi.encode(presale.rounds()), abi.encode(rounds));

        assertEq(presaleToken.balanceOf(address(presale)), _totalTokenAllocation());
    }

    function test_reverts_whenCalledMoreThanOnce() external {
        vm.startPrank(OWNER);

        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);

        vm.expectRevert("Initializable: contract is already initialized");
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);

        vm.expectRevert("Initializable: contract is already initialized");
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);

        vm.expectRevert("Initializable: contract is already initialized");
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);

        vm.stopPrank();
    }

    function test_reverts_whenCalledByANonOwner() external {
        vm.prank(ALICE);
        vm.expectRevert("Ownable: caller is not the owner");
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);
    }

    function test_reverts_whenCalledWithAnInvalidWithdrawToAddress() external {
        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidAddress.selector, address(0)));
        vm.prank(OWNER);
        presale.initialize(address(0), presaleConfig, rounds);
    }

    function test_reverts_whenCalledWithAnInvalidConfig() external {
        vm.startPrank(OWNER);

        IPresale.PresaleConfig memory newConfig = presaleConfig;

        newConfig.startDate = (block.timestamp - 1).toUint48();

        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidStartDate.selector, newConfig.startDate, block.timestamp));
        presale.initialize(WITHDRAW_TO, newConfig, rounds);

        newConfig = presaleConfig;
        newConfig.maxUserAllocation = 0;

        vm.expectRevert(abi.encodeWithSelector(PresaleInsufficientMaxUserAllocation.selector, 0, 1));
        presale.initialize(WITHDRAW_TO, newConfig, rounds);

        vm.stopPrank();
    }

    function test_reverts_whenCalledWithAnInvalidRounds() external {
        vm.expectRevert(abi.encodeWithSelector(PresaleInsufficientRounds.selector));
        vm.prank(OWNER);
        presale.initialize(WITHDRAW_TO, presaleConfig, new IPresale.RoundConfig[](0));
    }
}
