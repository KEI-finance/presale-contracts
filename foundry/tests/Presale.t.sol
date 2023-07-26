// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "forge-std/Test.sol";

import "contracts/PreSale.sol";

import "../mocks/TestERC20.sol";
import "../mocks/MockV3Aggregator.sol";

contract PresaleTest is Test {
    Presale internal presale;

    uint256 internal immutable PRECISION;
    uint256 internal immutable USD_PRECISION;
    uint256 internal immutable USDC_SCALE;

    address payable internal GLOBAL_ADMIN;

    address internal ALICE;
    address internal BOB;

    address payable internal withdrawTo;

    uint48 internal startDate;
    uint48 internal endDate;

    uint8 internal totalRounds;

    TestERC20 internal USDC;
    TestERC20 internal DAI;
    MockV3Aggregator internal ORACLE;
    IPresale.PresaleConfig internal config;
    IPresale.RoundConfig[] internal rounds;

    uint256[] internal tokenPrices;
    uint256[] internal tokensAllocated;

    constructor() {
        PRECISION = 1e8;
        USD_PRECISION = 1e18;
        USDC_SCALE = 1e12;

        GLOBAL_ADMIN = payable(makeAddr("GLOBAL_ADMIN"));
        vm.label(GLOBAL_ADMIN, "GLOBAL_ADMIN");

        ALICE = makeAddr("ALICE");
        vm.label(ALICE, "ALICE");

        BOB = makeAddr("BOB");
        vm.label(BOB, "BOB");

        withdrawTo = GLOBAL_ADMIN;

        startDate = 1 days;
        endDate = 10 days;

        totalRounds = 7;

        USDC = new TestERC20("USDC", "USDC");
        DAI = new TestERC20("DAI", "DAI");
        ORACLE = new MockV3Aggregator(8, int256(2000 * PRECISION));

        USDC.setDecimals(6);

        vm.deal(ALICE, 1_000 ether);
        vm.deal(BOB, 1_000 ether);

        USDC.mint(ALICE, 100_000 * 10 ** 6);
        USDC.mint(BOB, 100_000 * 10 ** 6);

        DAI.mint(ALICE, 100_000 ether);
        DAI.mint(BOB, 100_000 ether);

        config = IPresale.PresaleConfig({
            minDepositAmount: 1,
            maxUserAllocation: uint128(70_000 * PRECISION),
            startDate: startDate,
            endDate: endDate,
            withdrawTo: withdrawTo
        });

        tokenPrices = [
            70000000000000000,
            70000000000000000,
            80000000000000000,
            80000000000000000,
            90000000000000000,
            90000000000000000,
            100000000000000000
        ];

        for (uint256 i; i < totalRounds; ++i) {
            tokensAllocated.push(10_000 * PRECISION);

            IPresale.RoundConfig memory _round =
                IPresale.RoundConfig({tokenPrice: tokenPrices[i], tokensAllocated: tokensAllocated[i]});

            rounds.push(_round);
        }

        vm.startPrank(GLOBAL_ADMIN);
        presale = new Presale(address(ORACLE), address(USDC), address(DAI), config);
        presale.setConfig(config);
        presale.setRounds(rounds);
        vm.stopPrank();

        vm.startPrank(ALICE);
        USDC.approve(address(presale), type(uint256).max);
        DAI.approve(address(presale), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(BOB);
        USDC.approve(address(presale), type(uint256).max);
        DAI.approve(address(presale), type(uint256).max);
        vm.stopPrank();
    }

    modifier assertEvent() {
        vm.expectEmit(true, true, true, true);
        _;
    }
}

contract PresaleTest_currentRoundIndex is PresaleTest {
    function test_success() external {
        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseUSDC(701 * 1e6);

        assertEq(presale.currentRoundIndex(), 1);

        vm.prank(BOB);
        presale.purchaseDAI(700 * 1e18);

        assertEq(presale.currentRoundIndex(), 2);
    }
}

contract PresaleTest_config is PresaleTest {
    function test_success() external {
        IPresale.PresaleConfig memory _config = presale.config();

        assertEq(_config.minDepositAmount, config.minDepositAmount);
        assertEq(_config.maxUserAllocation, config.maxUserAllocation);
        assertEq(_config.startDate, config.startDate);
        assertEq(_config.endDate, config.endDate);
        assertEq(_config.withdrawTo, config.withdrawTo);
    }
}

contract PresaleTest_round is PresaleTest {
    function test_success() external {
        for (uint256 i; i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);

            assertEq(_round.tokenPrice, tokenPrices[i]);
            assertEq(_round.tokensAllocated, tokensAllocated[i]);
        }
    }
}

contract PresaleTest_rounds is PresaleTest {
    function test_success() external {
        IPresale.RoundConfig[] memory _rounds = presale.rounds();

        for (uint256 i; i < totalRounds; ++i) {
            assertEq(_rounds[i].tokenPrice, rounds[i].tokenPrice);
            assertEq(_rounds[i].tokensAllocated, rounds[i].tokensAllocated);
        }
    }
}

contract PresaleTest_totalRounds is PresaleTest {
    function test_success() external {
        assertEq(presale.totalRounds(), totalRounds);
    }
}

contract PresaleTest_roundAllocated is PresaleTest {
    uint256 private _availableToPurchaseUSD;

    function setUp() public {
        IPresale.RoundConfig memory _round = rounds[0];

        _availableToPurchaseUSD = _round.tokenPrice * _round.tokensAllocated / 1e26;

        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseUSDC(_availableToPurchaseUSD * 1e6);
    }

    function test_success() external {
        assertEq(presale.roundAllocated(0), tokensAllocated[0] * PRECISION);
    }
}

contract PresaleTest_totalRaisedUSD is PresaleTest {
    uint256 private _totalCostUSD;
    uint256[] private purchaseAmountsUSD;

    function setUp() public {
        vm.warp(startDate + 1);

        purchaseAmountsUSD = [700, 700, 800, 800, 100];

        //        uint256 _round1PurchaseAmountUSD = 700 * USD_PRECISION;
        //        uint256 _round2PurchaseAmountUSD = 700 * USD_PRECISION;
        //        uint256 _round3PurchaseAmountUSD = 800 * USD_PRECISION;
        //        uint256 _round4PurchaseAmountUSD = 100 * USD_PRECISION;
        //
        //        uint256 _round1Allocation = _round1PurchaseAmountUSD * PRECISION / rounds[0].tokenPrice;
        //        uint256 _round2Allocation = _round2PurchaseAmountUSD * PRECISION / rounds[1].tokenPrice;
        //        uint256 _round3Allocation = _round3PurchaseAmountUSD * PRECISION / rounds[2].tokenPrice;
        //        uint256 _round4Allocation = _round4PurchaseAmountUSD * PRECISION / rounds[3].tokenPrice;
        //
        //        uint256 _round1CostUSD = _round1PurchaseAmountUSD * rounds[0].tokenPrice / PRECISION;
        //        uint256 _round2CostUSD = _round2PurchaseAmountUSD * rounds[1].tokenPrice / PRECISION;
        //        uint256 _round3CostUSD = _round3PurchaseAmountUSD * rounds[2].tokenPrice / PRECISION;
        //        uint256 _round4CostUSD = _round4PurchaseAmountUSD * rounds[3].tokenPrice / PRECISION;
        //
        //        _totalCostUSD += _round1CostUSD;
        //        _totalCostUSD += _round2CostUSD;
        //        _totalCostUSD += _round3CostUSD;
        //        _totalCostUSD += _round4CostUSD;

        vm.prank(ALICE);
        presale.purchaseUSDC(2300 * 1e6);
    }

    function test_success() external {
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
    }
}

contract PresaleTest_userTokensAllocated is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_ethPrice is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_ethToUsd is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_usdToTokens is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_setConfig is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotOwner() external {}

    function test_rejects_whenInvalidDates() external {}

    function test_rejects_whenInvalidWithdrawTo() external {}

    function test_emit_ConfigUpdated() external {}
}

contract PresaleTest_setRounds is PresaleTest {
    IPresale.RoundConfig[] internal _newRounds;
    uint256 internal _totalRounds;

    function setUp() public {
        _totalRounds = 10;

        for (uint256 i; i < _totalRounds; ++i) {
            IPresale.RoundConfig memory _round = IPresale.RoundConfig({tokenPrice: i * 10, tokensAllocated: i * 100});

            _newRounds.push(_round);
        }
    }

    function test_success() external {}

    function test_rejects_whenNotOwner() external {}

    function test_emits_RoundsUpdated() external {}
}

contract PresaleTest_purchase is PresaleTest {
    function test_success() external {}

    function test_rejects_whenPaused() external {}

    function test_rejects_whenRaiseNotStarted() external {}

    function test_rejects_whenRaiseEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_emits_Receipt() external {}
}

contract PresaleTest_purchaseForAccount is PresaleTest {
    function test_success() external {}

    function test_rejects_whenPaused() external {}

    function test_rejects_whenRaiseNotStarted() external {}

    function test_rejects_whenRaiseEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_emits_Receipt() external {}
}

contract PresaleTest_purchaseUSDC is PresaleTest {
    function test_success() external {}

    function test_rejects_whenPaused() external {}

    function test_rejects_whenRaiseNotStarted() external {}

    function test_rejects_whenRaiseEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_emits_Receipt() external {}
}

contract PresaleTest_purchaseDAI is PresaleTest {
    function test_success() external {}

    function test_rejects_whenPaused() external {}

    function test_rejects_whenRaiseNotStarted() external {}

    function test_rejects_whenRaiseEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_emits_Receipt() external {}
}
