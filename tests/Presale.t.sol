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

        vm.warp(presaleConfig.startDate - 1);
        vm.prank(OWNER);
        presale.initialize(WITHDRAW_TO, presaleConfig, rounds);
    }

    function test_construct() external {}

    function _createContracts() internal {
        presaleToken = new PlaceholderToken(OWNER, _totalTokenAllocation());
        presaleAsset = new ERC20Mock("USDT", "USDT");
        presale = new Presale(IERC20(address(presaleAsset)), IERC20(address(presaleToken)), OWNER);
        presaleRouter = new PresaleRouter(0, 0, 2, presale, swapRouter, IStargateRouter(address(swapRouter)));

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

    function _remainingAssetAllocation() internal view returns (uint256 remainingAssetAllocation) {
        return _remainingAssetAllocation(presale.totalRounds());
    }

    function _remainingAssetAllocation(uint256 _maxRounds) internal view returns (uint256 remainingAssetAllocation) {
        uint256 totalRounds = presale.totalRounds();
        for (uint256 i = presale.currentRoundIndex(); i < totalRounds && i < _maxRounds; i++) {
            remainingAssetAllocation = _remainingRoundAssetAllocation(i);
        }
    }

    function _remainingRoundAssetAllocation(uint256 roundIndex) internal view returns (uint256 remainingAssetAllocation) {
        uint256 tokensAllocated = presale.roundTokensAllocated(roundIndex);
        IPresale.RoundConfig memory round = presale.round(roundIndex);
        remainingAssetAllocation += round.allocation > tokensAllocated ? round.allocation  - tokensAllocated : 0;
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

    event ConfigUpdate(IPresale.PresaleConfig newConfig, address indexed sender);

    event WithdrawToUpdate(address newWithdrawTo, address indexed sender);

    event RoundsUpdate(IPresale.RoundConfig[] newRounds, address indexed sender);

    function setUp() public virtual override {
        // cancel initialization
    }

    function test_success() external {
        assertEq(presale.totalRounds(), 0);
        assertNotEq0(abi.encode(presale.config()), abi.encode(presaleConfig));
        assertNotEq0(abi.encode(presale.rounds()), abi.encode(rounds));

        vm.expectEmit(true, true, true, true, address(presale));
        emit WithdrawToUpdate(WITHDRAW_TO, OWNER);
        vm.expectEmit(true, true, true, true, address(presale));
        emit ConfigUpdate(presaleConfig, OWNER);
        vm.expectEmit(true, true, true, true, address(presale));
        emit RoundsUpdate(rounds, OWNER);

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

contract PresaleTest__close is PresaleTest {
    event Close();

    function test_success() external {
        vm.expectEmit(true, true, true, true, address(presale));
        emit Close();

        uint256 prevBalance = presaleToken.balanceOf(address(presale));
        assertGt(prevBalance, 0);

        vm.prank(OWNER);
        presale.close();

        assertEq(presaleToken.balanceOf(address(presale)), 0);
        assertEq(presaleToken.balanceOf(WITHDRAW_TO), prevBalance);

        assertTrue(presale.closed());
    }

    function test_success_whenPresaleHasNoTokensRemaining() external {
        deal(address(presaleToken), address(presale), 0);

        assertEq(presaleToken.balanceOf(address(presale)), 0);

        vm.prank(OWNER);
        presale.close();

        assertEq(presaleToken.balanceOf(address(presale)), 0);
    }

    function test_reverts_whenCalledMoreThanOnce() external {
        vm.startPrank(OWNER);

        presale.close();

        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidState.selector, PresaleState.CLOSED));
        presale.close();

        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidState.selector, PresaleState.CLOSED));
        presale.close();

        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidState.selector, PresaleState.CLOSED));
        presale.close();

        vm.stopPrank();
    }

    function test_reverts_whenCalledByNonOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");
        presale.close();
    }
}

contract PresaleTest__setWithdrawTo is PresaleTest {
    event WithdrawToUpdate(address newWithdrawTo, address indexed sender);

    function test_success(address newWithdrawTo) external {
        vm.assume(newWithdrawTo != address(0) && WITHDRAW_TO != newWithdrawTo);

        assertEq(presale.withdrawTo(), WITHDRAW_TO);

        vm.expectEmit(true, true, true, true, address(presale));
        emit WithdrawToUpdate(newWithdrawTo, OWNER);

        vm.prank(OWNER);
        presale.setWithdrawTo(newWithdrawTo);

        assertEq(presale.withdrawTo(), newWithdrawTo);
    }

    function test_reverts_whenNotCalledByOwner(address newWithdrawTo) external {
        vm.expectRevert("Ownable: caller is not the owner");
        presale.setWithdrawTo(newWithdrawTo);
    }

    function test_reverts_whenUsingTheSameWithdrawTo() external {
        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidAddress.selector, WITHDRAW_TO));
        vm.prank(OWNER);
        presale.setWithdrawTo(WITHDRAW_TO);
    }
}

contract PresaleTest__purchase is PresaleTest {
    function setUp() public override virtual {
        super.setUp();

        vm.warp(presaleConfig.startDate);
        vm.prank(ALICE);
        presaleAsset.approve(address(presale), type(uint256).max);
    }

    function test_success(address account, uint128 assetAmount) external {
        uint256 price = presale.round(0).price;
        vm.assume(presale.assetsToTokens(assetAmount, price) > 0 && account != address(0));

        presaleAsset.mint(ALICE, assetAmount);
        vm.prank(ALICE);
        IPresale.Receipt memory receipt = presale.purchase(account, assetAmount);

        assertEq(presaleToken.balanceOf(account), receipt.tokensAllocated);
        assertEq(presaleAsset.balanceOf(ALICE), receipt.refundedAssets);
        assertEq(presaleAsset.balanceOf(WITHDRAW_TO), receipt.costAssets);
    }

    function test_reverts_whenAccountIsAZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidAddress.selector, address(0)));
        presale.purchase(address(0), 1000);
    }

    function test_reverts_whenBlockTimestampIsLessThanStartDate() external {
        vm.warp(presaleConfig.startDate - 1);
        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidState.selector, PresaleState.NOT_STARTED));
        presale.purchase(ALICE, 1000);
    }

    function test_reverts_whenAssetAmountIsZero() external {
        assertEq(presale.config().minDepositAmount, 0);
        vm.expectRevert(abi.encodeWithSelector(PresaleInsufficientAmount.selector, 0, 1));
        presale.purchase(ALICE, 0);
    }

    function test_reverts_whenAssetAmountIsLessThanMinDepositAmount() external {
        presaleConfig.minDepositAmount = 100;

        _createContracts();
        setUp();

        assertEq(presale.config().minDepositAmount, 100);

        presaleAsset.mint(ALICE, 50);
        vm.expectRevert(abi.encodeWithSelector(PresaleInsufficientAmount.selector, 50, 100));
        presale.purchase(ALICE, 50);
    }

    function test_reverts_whenClosed() external {
        vm.prank(OWNER);
        presale.close();

        presaleAsset.mint(ALICE, 100);

        vm.expectRevert(abi.encodeWithSelector(PresaleInvalidState.selector, PresaleState.CLOSED));
        vm.prank(ALICE);
        presale.purchase(ALICE, 100);
    }

    function test_success_whenPurchasingMaximumAllocation(address account, uint64 refundedAmount) external {
        uint256 assetAmount = _remainingAssetAllocation() + refundedAmount;

        presaleAsset.mint(ALICE, assetAmount);
        vm.prank(ALICE);
        presale.purchase(account, assetAmount);

    }

    function test_success_whenPurchasingOneRoundAtATime() external {

    }
}
