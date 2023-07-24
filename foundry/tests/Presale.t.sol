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

        USDC.mint(ALICE, 1_000 * 10 ** 6);
        USDC.mint(BOB, 1_000 * 10 ** 6);

        DAI.mint(ALICE, 1_000 ether);
        DAI.mint(BOB, 1_000 ether);

        config = IPresale.PresaleConfig({
            minDepositAmount: 1,
            maxUserAllocation: uint128(70_000 * PRECISION),
            startDate: startDate,
            endDate: endDate,
            withdrawTo: withdrawTo
        });

        // tokenPrice = how many tokens for 1 usd
        // tokens allocated in round = _roundRemaining * tokenPrice;

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

            IPresale.RoundConfig memory _round = IPresale.RoundConfig({
                tokenPrice: tokenPrices[i],
                tokensAllocated: tokensAllocated[i]
            });

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
        presale.purchaseUSDC(701 * (10 ** 6));

        assertEq(presale.currentRoundIndex(), 1);
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
    function test_success() external {}
}

contract PresaleTest_totalRounds is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_roundAllocated is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_totalRaisedUSD is PresaleTest {
    function test_success() external {}
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
