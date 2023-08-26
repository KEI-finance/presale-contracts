//// SPDX-License-Identifier: UNLICENSED
//
//pragma solidity =0.8.19;
//
//import "forge-std/Test.sol";
//
//import "contracts/PreSale.sol";
//
//import "./mocks/TestERC20.sol";
//
//contract PresaleTest is Test {
//    Presale internal presale;
//
//    uint256 internal immutable PRECISION;
//
//    address payable internal GLOBAL_ADMIN;
//
//    address internal ALICE;
//    address internal BOB;
//
//    address payable internal WITHDRAW_TO;
//
//    uint48 internal startDate;
//
//    uint8 internal totalRounds;
//
//    TestERC20 internal PRESALE_TOKEN;
//    IPresale.PresaleConfig internal config;
//    IPresale.RoundConfig[] internal rounds;
//
//    uint256[] internal tokenPrices;
//    uint256[] internal tokensAllocated;
//
//    uint256 internal aliceAllocationRemaining;
//    uint256 internal bobAllocationRemaining;
//
//    uint256 internal aliceEthBalance;
//    uint256 internal bobEthBalance;
//    uint256 internal withdrawToEthBalance;
//
//    uint256 internal aliceAssetsBalance;
//    uint256 internal bobAssetsBalance;
//    uint256 internal withdrawToAssetsBalance;
//
//    uint256 internal aliceDaiBalance;
//    uint256 internal bobDaiBalance;
//    uint256 internal withdrawToDaiBalance;
//
//    constructor() {
//        PRECISION = 1e8;
//
//        GLOBAL_ADMIN = payable(makeAddr("GLOBAL_ADMIN"));
//        vm.label(GLOBAL_ADMIN, "GLOBAL_ADMIN");
//
//        ALICE = makeAddr("ALICE");
//        vm.label(ALICE, "ALICE");
//
//        BOB = makeAddr("BOB");
//        vm.label(BOB, "BOB");
//
//        WITHDRAW_TO = payable(makeAddr("WITHDRAW_TO"));
//        vm.label(WITHDRAW_TO, "WITHDRAW_TO");
//
//        startDate = 1 days;
//
//        totalRounds = 7;
//
//        PRESALE_TOKEN = new TestERC20("DAI", "DAI");
//
//        vm.deal(ALICE, 1_000 ether);
//        vm.deal(BOB, 1_000 ether);
//        vm.deal(GLOBAL_ADMIN, 1_000 ether);
//        vm.deal(WITHDRAW_TO, 1_000 ether);
//        vm.deal(address(presale), 100_000 ether);
//
//        PRESALE_TOKEN.mint(ALICE, 100_000 * 10 ** 6);
//        PRESALE_TOKEN.mint(BOB, 100_000 * 10 ** 6);
//
//        PRESALE_TOKEN.mint(ALICE, 100_000 ether);
//        PRESALE_TOKEN.mint(BOB, 100_000 ether);
//
//        config = IPresale.PresaleConfig({
//            minDepositAmount: 1 ether,
//            maxUserAllocation: uint128(70_000 * PRECISION),
//            startDate: startDate,
//            withdrawTo: WITHDRAW_TO
//        });
//
//        tokenPrices = [0.07 ether, 0.07 ether, 0.08 ether, 0.08 ether, 0.09 ether, 0.09 ether, 0.1 ether];
//
//        for (uint256 i; i < totalRounds; ++i) {
//            tokensAllocated.push(10_000 * PRECISION);
//
//            IPresale.RoundConfig memory _round = IPresale.RoundConfig({
//                tokenPrice: tokenPrices[i],
//                tokenAllocation: tokensAllocated[i],
//                roundType: IPresale.RoundType.Tokens
//            });
//
//            rounds.push(_round);
//        }
//
//        vm.startPrank(GLOBAL_ADMIN);
//        presale = new Presale(address(PRESALE_TOKEN), config, rounds);
//        vm.stopPrank();
//
//        vm.startPrank(ALICE);
//        PRESALE_TOKEN.approve(address(presale), type(uint256).max);
//        vm.stopPrank();
//
//        vm.startPrank(BOB);
//        PRESALE_TOKEN.approve(address(presale), type(uint256).max);
//        vm.stopPrank();
//
//        aliceAllocationRemaining = config.maxUserAllocation;
//        bobAllocationRemaining = config.maxUserAllocation;
//
//        aliceEthBalance = ALICE.balance;
//        bobEthBalance = BOB.balance;
//        withdrawToEthBalance = address(config.withdrawTo).balance;
//
//        aliceAssetsBalance = PRESALE_TOKEN.balanceOf(ALICE);
//        bobAssetsBalance = PRESALE_TOKEN.balanceOf(BOB);
//        withdrawToAssetsBalance = PRESALE_TOKEN.balanceOf(address(config.withdrawTo));
//
//        aliceDaiBalance = PRESALE_TOKEN.balanceOf(ALICE);
//        bobDaiBalance = PRESALE_TOKEN.balanceOf(BOB);
//        withdrawToDaiBalance = PRESALE_TOKEN.balanceOf(address(config.withdrawTo));
//    }
//
//    function _fillRounds(address account, uint256 amountAsset)
//        internal
//        view
//        returns (uint256 _totalCostAssets, uint256 _totalAllocation, uint256 _newRoundIndex)
//    {
//        uint256 _remainingAssets = amountAsset;
//        uint256 _userAllocationRemaining = config.maxUserAllocation - presale.userTokensAllocated(account);
//
//        _newRoundIndex = presale.currentRoundIndex();
//
//        while (_newRoundIndex < rounds.length && _remainingAssets > 0 && _userAllocationRemaining > 0) {
//            IPresale.RoundConfig memory _round = presale.round(_newRoundIndex);
//            uint256 _roundTotalAllocated = presale.roundTokensAllocated(_newRoundIndex);
//            uint256 _roundAllocationRemaining =
//                _roundTotalAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundTotalAllocated : 0;
//
//            uint256 _userAllocation = presale.assetsToTokens(_remainingAssets, _round.tokenPrice);
//
//            if (_userAllocation > _roundAllocationRemaining) {
//                _userAllocation = _roundAllocationRemaining;
//            }
//            if (_userAllocation > _userAllocationRemaining) {
//                _userAllocation = _userAllocationRemaining;
//            }
//
//            if (_userAllocation > 0) {
//                uint256 _costAssets = presale.tokensToAssets(_userAllocation, _round.tokenPrice);
//
//                _userAllocationRemaining -= _userAllocation;
//                _totalAllocation += _userAllocation;
//                _totalCostAssets += _costAssets;
//                _remainingAssets -= _costAssets;
//            }
//
//            // if we have used everything then lets increment current index. and only increment if we are not on the last round.
//            if (_userAllocation == _roundAllocationRemaining && _newRoundIndex < totalRounds - 1) {
//                _newRoundIndex++;
//            } else {
//                break;
//            }
//        }
//    }
//
//    modifier assertEvent() {
//        vm.expectEmit(true, true, true, true);
//        _;
//    }
//}
//
//contract PresaleTest_currentRoundIndex is PresaleTest {
//    function test_success() external {
//        vm.warp(startDate + 1);
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, 700 ether, "");
//
//        assertEq(presale.currentRoundIndex(), 1);
//
//        vm.prank(BOB);
//        presale.purchase(BOB, 700 ether, "");
//
//        assertEq(presale.currentRoundIndex(), 2);
//    }
//}
//
//contract PresaleTest_config is PresaleTest {
//    function test_success() external {
//        IPresale.PresaleConfig memory _config = presale.config();
//
//        assertEq(_config.minDepositAmount, config.minDepositAmount);
//        assertEq(_config.maxUserAllocation, config.maxUserAllocation);
//        assertEq(_config.startDate, config.startDate);
//        assertEq(_config.withdrawTo, config.withdrawTo);
//    }
//}
//
//contract PresaleTest_round is PresaleTest {
//    function test_success() external {
//        for (uint256 i; i < totalRounds; ++i) {
//            IPresale.RoundConfig memory _round = presale.round(i);
//
//            assertEq(_round.tokenPrice, tokenPrices[i]);
//            assertEq(_round.tokenAllocation, tokensAllocated[i]);
//        }
//    }
//}
//
//contract PresaleTest_rounds is PresaleTest {
//    function test_success() external {
//        IPresale.RoundConfig[] memory _rounds = presale.rounds();
//
//        for (uint256 i; i < totalRounds; ++i) {
//            assertEq(_rounds[i].tokenPrice, rounds[i].tokenPrice);
//            assertEq(_rounds[i].tokenAllocation, rounds[i].tokenAllocation);
//        }
//    }
//}
//
//contract PresaleTest_totalRounds is PresaleTest {
//    function test_success() external {
//        assertEq(presale.totalRounds(), totalRounds);
//    }
//}
//
//contract PresaleTest_roundAllocated is PresaleTest {
//    uint256 private _availableToPurchase;
//
//    function setUp() public {
//        IPresale.RoundConfig memory _round = rounds[0];
//
//        _availableToPurchase = _round.tokenPrice * _round.tokenAllocation / PRECISION;
//
//        vm.warp(startDate + 1);
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, _availableToPurchase * 1e6, "");
//    }
//
//    function test_success() external {
//        assertEq(presale.roundTokensAllocated(0), tokensAllocated[0]);
//    }
//}
//
//contract PresaleTest_liquidityType is PresaleTest {
//    constructor() {
//        IPresale.RoundConfig[] memory _rounds = new IPresale.RoundConfig[](2);
//
//        _rounds[0] = IPresale.RoundConfig({
//            tokenPrice: 0.07 ether,
//            tokenAllocation: 10_000 ether,
//            roundType: IPresale.RoundType.Liquidity
//        });
//
//        _rounds[1] = IPresale.RoundConfig({
//            tokenPrice: 0.09 ether,
//            tokenAllocation: 10_000 ether,
//            roundType: IPresale.RoundType.Liquidity
//        });
//
//        presale = new Presale(address(PRESALE_TOKEN), config, _rounds);
//
//        vm.prank(ALICE);
//        PRESALE_TOKEN.approve(address(presale), type(uint256).max);
//    }
//
//    function test_success() external {
//        vm.warp(startDate);
//
//        uint256 _alicePurchaseAmountAsset = 1e6 ether;
//
//        vm.prank(ALICE);
//        IPresale.Receipt memory _receipt = presale.purchase(ALICE, _alicePurchaseAmountAsset, "");
//
//        assertEq(presale.userLiquidityAllocated(ALICE), (_alicePurchaseAmountAsset - _receipt.refundedAssets) / 2);
//        assertEq(presale.userLiquidityAllocated(ALICE), _receipt.liquidityAssets);
//        assertEq(presale.userTokensAllocated(ALICE), _receipt.tokensAllocated);
//        assertEq(_receipt.costAssets, _receipt.liquidityAssets * 2);
//    }
//}
//
//contract PresaleTest_totalRaised is PresaleTest {
//    function test_success() external {
//        vm.warp(startDate);
//
//        uint256 _purchaseAmount = 1_234 ether;
//
//        (uint256 _totalCost,,) = _fillRounds(ALICE, _purchaseAmount);
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, _purchaseAmount, "");
//
//        assertEq(presale.totalRaised(), _totalCost);
//    }
//}
//
//contract PresaleTest_userTokensAllocated is PresaleTest {
//    function test_success() external {
//        vm.warp(startDate + 1);
//
//        uint256 _purchaseAmounts = 2301 ether;
//
//        (, uint256 _totalAllocation,) = _fillRounds(ALICE, _purchaseAmounts);
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, _purchaseAmounts, "");
//
//        assertEq(presale.userTokensAllocated(ALICE), _totalAllocation);
//    }
//}
//
//contract PresaleTest_assetsToTokens is PresaleTest {
//    function test_success() external {
//        IPresale.RoundConfig memory _round = presale.round(0);
//        uint256 _assetAmount = 100 ether;
//        uint256 _tokenAmount = _assetAmount * PRECISION / _round.tokenPrice;
//        assertEq(presale.assetsToTokens(_assetAmount, _round.tokenPrice), _tokenAmount);
//    }
//}
//
//contract PresaleTest_close is PresaleTest {
//    event Close();
//
//    function test_success() external {
//        vm.prank(GLOBAL_ADMIN);
//
//        assertFalse(presale.closed());
//
//        vm.prank(GLOBAL_ADMIN);
//        presale.close();
//
//        assertTrue(presale.closed());
//    }
//
//    function test_rejects_whenClosed() external {
//        vm.startPrank(GLOBAL_ADMIN);
//        presale.close();
//
//        vm.expectRevert("PRESALE_ALREADY_CLOSED");
//        presale.close();
//
//        vm.stopPrank();
//    }
//
//    function test_rejects_whenNotOwner() external {
//        vm.expectRevert("Ownable: caller is not the owner");
//
//        vm.prank(ALICE);
//        presale.close();
//    }
//
//    function test_emits_Close() external assertEvent {
//        vm.prank(GLOBAL_ADMIN);
//        emit Close();
//        presale.close();
//    }
//}
//
//contract PresaleTest_purchase is PresaleTest {
//    event Purchase(
//        uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountAssets, uint256 tokensAllocated
//    );
//
//    uint256 private _totalCostAssets;
//    uint256 private _totalAllocation;
//
//    uint256 private _aliceTotalCostAssets;
//    uint256 private _bobTotalCostAssets;
//
//    function test_success(uint256 _alicePurchaseAmountAsset, uint256 _bobPurchaseAmountAsset) external {
//        vm.assume(_alicePurchaseAmountAsset != 0);
//        vm.assume(_bobPurchaseAmountAsset != 0);
//
//        _alicePurchaseAmountAsset = bound(_alicePurchaseAmountAsset, 1e6, aliceAssetsBalance);
//        _bobPurchaseAmountAsset = bound(_bobPurchaseAmountAsset, 1e6, bobAssetsBalance);
//
//        uint256 _alicePurchaseAmount = _alicePurchaseAmountAsset * 1 ether;
//        uint256 _bobPurchaseAmount = _bobPurchaseAmountAsset * 1 ether;
//
//        vm.warp(startDate);
//
//        (uint256 _aliceCost, uint256 _aliceAllocation, uint256 _aliceNewRoundIndex) =
//            _fillRounds(ALICE, _alicePurchaseAmount);
//
//        _totalCostAssets += _aliceCost;
//        _totalAllocation += _aliceAllocation;
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, _alicePurchaseAmount, "");
//
//        // ensure bob has something to purchase
//        uint256 currentIndex = presale.currentRoundIndex();
//
//        if (presale.round(currentIndex).tokenAllocation <= presale.roundTokensAllocated(currentIndex)) {
//            return;
//        }
//
//        assertEq(presale.currentRoundIndex(), _aliceNewRoundIndex);
//        assertEq(presale.totalRaised(), _totalCostAssets);
//        assertEq(presale.userTokensAllocated(ALICE), _aliceAllocation);
//
//        assertEq(PRESALE_TOKEN.balanceOf(ALICE), aliceAssetsBalance - _alicePurchaseAmount);
//        assertEq(PRESALE_TOKEN.balanceOf(config.withdrawTo), withdrawToAssetsBalance + _alicePurchaseAmount);
//
//        (uint256 _bobCostAssets, uint256 _bobAllocation, uint256 _bobNewRoundIndex) =
//            _fillRounds(BOB, _bobPurchaseAmount);
//
//        _totalCostAssets += _bobCostAssets;
//        _totalAllocation += _bobAllocation;
//
//        vm.prank(BOB);
//        IPresale.Receipt memory _receipt = presale.purchase(BOB, _bobPurchaseAmount, "");
//
//        assertEq(presale.currentRoundIndex(), _bobNewRoundIndex);
//        assertEq(presale.totalRaised(), _totalCostAssets);
//        assertEq(presale.userTokensAllocated(BOB), _bobAllocation);
//
//        assertEq(PRESALE_TOKEN.balanceOf(BOB), bobAssetsBalance - _alicePurchaseAmount + _receipt.refundedAssets);
//        assertEq(
//            PRESALE_TOKEN.balanceOf(config.withdrawTo),
//            withdrawToAssetsBalance + _bobPurchaseAmount + _alicePurchaseAmount - _receipt.refundedAssets
//        );
//    }
//
//    function test_rejects_whenClosed() external {
//        vm.warp(startDate);
//
//        vm.prank(GLOBAL_ADMIN);
//        presale.close();
//
//        vm.expectRevert("PRESALE_CLOSED");
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, 5_000 * 1e6, "");
//    }
//
//    function test_rejects_whenRaiseNotStarted() external {
//        vm.warp(startDate - 1);
//
//        vm.expectRevert("PRESALE_NOT_STARTED");
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, 5_000 * 1e6, "");
//    }
//
//    function test_rejects_whenMinDepositAmount() external {
//        vm.warp(startDate);
//
//        vm.expectRevert("MIN_DEPOSIT_AMOUNT");
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, 0.1 * 1e6, "");
//    }
//
//    function test_emits_Purchase() external {
//        uint256 _alicePurchaseAmountAsset = 1_345 * 1e6;
//        uint256 _alicePurchaseAmount = _alicePurchaseAmountAsset * 1 ether;
//
//        uint256 _receiptId = presale.totalPurchases() + 1;
//
//        vm.warp(startDate);
//
//        vm.expectEmit(true, true, true, true);
//
//        uint256 _remainingAssets = _alicePurchaseAmount;
//        for (uint256 i = presale.currentRoundIndex(); i < totalRounds; ++i) {
//            IPresale.RoundConfig memory _round = presale.round(i);
//            uint256 _roundAllocated = presale.roundTokensAllocated(i);
//            uint256 _roundAllocationRemaining =
//                _roundAllocated < _round.tokenAllocation ? _round.tokenAllocation - _roundAllocated : 0;
//
//            uint256 _roundAllocation = _remainingAssets * PRECISION / _round.tokenPrice;
//
//            if (_roundAllocation > _roundAllocationRemaining) {
//                _roundAllocation = _roundAllocationRemaining;
//            }
//
//            _totalAllocation += _roundAllocation;
//
//            uint256 _costAssets = _roundAllocation * _round.tokenPrice / PRECISION;
//            _totalCostAssets += _costAssets;
//
//            emit Purchase(_receiptId, i, _costAssets, _roundAllocation);
//
//            _remainingAssets -= _costAssets;
//
//            if (_remainingAssets == 0) {
//                break;
//            }
//        }
//
//        vm.prank(ALICE);
//        presale.purchase(ALICE, _alicePurchaseAmount, "");
//    }
//}
