// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "forge-std/Test.sol";

import "contracts/PreSale.sol";

import "../mocks/TestERC20.sol";
import "../mocks/MockV3Aggregator.sol";

contract PresaleTest is Test {
    Presale internal presale;

    address payable internal GLOBAL_ADMIN;

    address internal ALICE;
    address internal BOB;

    uint48 internal startsAt;
    uint48 internal endsAt;

    TestERC20 internal USDC;
    TestERC20 internal DAI;
    MockV3Aggregator internal ORACLE;

    IPresale.Round[] internal rounds;

    uint256[] internal allocationsUSD;

    function setUp() public virtual {
        GLOBAL_ADMIN = payable(makeAddr("GLOBAL_ADMIN"));
        ALICE = makeAddr("ALICE");
        BOB = makeAddr("BOB");

        startsAt = 1 days;
        endsAt = 10 days;

        USDC = new TestERC20("USDC", "USDC");
        DAI = new TestERC20("DAI", "DAI");
        ORACLE = new MockV3Aggregator(8, 2000 * 10 ** 8);

        USDC.setDecimals(6);

        vm.deal(ALICE, 50_000 ether);
        vm.deal(BOB, 50_000 ether);

        USDC.mint(ALICE, 1000 * 10 ** 6);
        USDC.mint(BOB, 1000 * 10 ** 6);

        DAI.mint(ALICE, 1_000_000 ether);
        DAI.mint(BOB, 1_000_000 ether);

        vm.prank(GLOBAL_ADMIN);
        presale = new Presale(startsAt, endsAt, GLOBAL_ADMIN, address(ORACLE), address(USDC), address(DAI));

        allocationsUSD = [7_000, 8_000, 8_000, 9_000, 9_000, 10_000, 10_000];

        for (uint256 i; i < 7; ++i) {
            IPresale.Round memory round_ = IPresale.Round({
                allocationUSD: allocationsUSD[i] * 1 ether,
                userCapUSD: 10_000 ether,
                minDepositUSD: 1 ether,
                tokenAllocation: 100_000 ether,
                totalRaisedUSD: 0
            });
            rounds.push(round_);
        }

        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(rounds);

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

contract PresaleTest_startsAt is PresaleTest {
    function test_success() external {
        assertEq(presale.startsAt(), startsAt);
    }
}

contract PresaleTest_endsAt is PresaleTest {
    function test_success() external {
        assertEq(presale.endsAt(), endsAt);
    }
}

contract PresaleTest_totalRounds is PresaleTest {
    function test_success() external {
        assertEq(presale.totalRounds(), 7);
    }
}

contract PresaleTest_totalRaisedUSD is PresaleTest {
    function setUp() public override {
        super.setUp();

        vm.warp(1 days + 1);

        vm.startPrank(ALICE);
        presale.depositDAI(62_000 ether);
        vm.stopPrank();
    }

    function test_success() external {
        assertEq(presale.totalRaisedUSD(), 61_000 ether);
    }
}

contract PresaleTest_raisedUSD is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_roundDepositUSD is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_roundTokensAllocated is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_depositsUSD is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_tokensAllocated is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_ethPrice is PresaleTest {
    function test_success() external {
        assertEq(presale.ethPrice(), 2000 * 10 ** 18);
    }
}

contract PresaleTest_ethToUsd is PresaleTest {
    function test_success() external {
        assertEq(presale.ethToUsd(1 * 10 ** 18), 2000 * 10 ** 18);
    }
}

contract PresaleTest_usdToTokens is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_updateDates is PresaleTest {
    event DatesUpdated(
        uint256 prevStartsAt, uint256 newStartsAt, uint256 prevEndsAt, uint256 newEndsAt, address indexed sender
    );

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.updateDates(10 days, 20 days);

        assertEq(presale.startsAt(), 10 days);
        assertEq(presale.endsAt(), 20 days);
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.updateDates(10 days, 20 days);
    }

    function test_rejects_whenInvalidDates() external {
        vm.expectRevert("INVALID_DATES");

        vm.prank(GLOBAL_ADMIN);
        presale.updateDates(10 days, 5 days);
    }

    function test_emits_DatesUpdated() external assertEvent {
        emit DatesUpdated(startsAt, 10 days, endsAt, 20 days, GLOBAL_ADMIN);

        vm.prank(GLOBAL_ADMIN);
        presale.updateDates(10 days, 20 days);
    }
}

contract PresaleTest_setWithdrawTo is PresaleTest {
    event WithdrawToUpdated(address prevWithdrawTo, address newWithdrawTo, address sender);

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.setWithdrawTo(payable(ALICE));

        assertEq(presale.$withdrawTo(), payable(ALICE));
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.setWithdrawTo(payable(ALICE));
    }

    function test_rejects_whenAddressZero() external {
        vm.expectRevert("INVALID_WITHDRAW_TO");

        vm.prank(GLOBAL_ADMIN);
        presale.setWithdrawTo(payable(address(0)));
    }

    function test_emits_WithdrawToUpdated() external assertEvent {
        emit WithdrawToUpdated(GLOBAL_ADMIN, ALICE, GLOBAL_ADMIN);

        vm.prank(GLOBAL_ADMIN);
        presale.setWithdrawTo(payable(ALICE));
    }
}

contract PresaleTest_setRounds is PresaleTest {
    event RoundSet(uint256 roundIndex, IPresale.Round round, address indexed sender);

    IPresale.Round[] internal _rounds;

    uint256 internal totalRounds;

    function setUp() public override {
        super.setUp();

        totalRounds = 5;

        for (uint256 i; i < totalRounds; ++i) {
            IPresale.Round memory round_ = IPresale.Round({
                allocationUSD: 10_000 * (i + 1),
                userCapUSD: 50_000,
                minDepositUSD: 1,
                tokenAllocation: 20_000 * (i + 1),
                totalRaisedUSD: 0
            });
            _rounds.push(round_);
        }
    }

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_rounds);

        assertEq(presale.totalRounds(), totalRounds);

        for (uint256 i; i < totalRounds; ++i) {
            IPresale.Round memory _round = presale.rounds(i);

            assertEq(_round.allocationUSD, 10_000 * (i + 1));
            assertEq(_round.userCapUSD, 50_000);
            assertEq(_round.minDepositUSD, 1);
            assertEq(_round.tokenAllocation, 20_000 * (i + 1));
            assertEq(_round.totalRaisedUSD, 0);
        }
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.setRounds(_rounds);
    }

    function test_emits_RoundSet() external assertEvent {
        for (uint256 i; i < totalRounds; ++i) {
            IPresale.Round memory _round = _rounds[i];
            emit RoundSet(i, _round, GLOBAL_ADMIN);
        }
        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_rounds);
    }
}

contract PresaleTest_withdraw is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotOwner() external {}

    function test_emits_Withdrawal() external {}
}

contract PresaleTest_depositETH is PresaleTest {
    function test_success() external {
        vm.warp(1 days + 1);

        vm.prank(ALICE);
        presale.depositETH{value: 2 ether}();

        assertEq(presale.depositsUSD(ALICE), presale.ethToUsd(2 ether));
        assertEq(presale.tokensAllocated(ALICE), presale.usdToTokens(0, presale.ethToUsd(2 ether)));
        assertEq(presale.totalRaisedUSD(), presale.ethToUsd(2 ether));
        assertEq(presale.roundTokensAllocated(0, ALICE), presale.usdToTokens(0, presale.ethToUsd(2 ether)));
    }

    function test_success_acrossMultipleRounds() external {
        vm.warp(1 days + 1);

        vm.prank(ALICE);
        presale.depositETH{value: 4 ether}();

        assertEq(presale.depositsUSD(ALICE), presale.ethToUsd(4 ether));

        assertEq(presale.tokensAllocated(ALICE), rounds[0].tokenAllocation + presale.usdToTokens(1, 1_000 ether));

        assertEq(presale.roundTokensAllocated(0, ALICE), rounds[0].tokenAllocation);
        assertEq(presale.roundTokensAllocated(1, ALICE), presale.usdToTokens(1, 1_000 ether));

        assertEq(presale.totalRaisedUSD(), presale.ethToUsd(4 ether));
    }

    function test_success_refundsOverspentAmount() external {
        uint256 aliceBalance = ALICE.balance;

        vm.warp(1 days + 1);

        vm.prank(ALICE);
        presale.depositETH{value: 31 ether}(); // overspending by 0.5 ether

        assertEq(address(presale).balance, 30.5 ether);
        assertEq(ALICE.balance, aliceBalance - 30.5 ether);
    }

    function test_rejects_whenNotStarted() external {
        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(ALICE);
        presale.depositETH{value: 2 ether}();
    }

    function test_rejects_whenEnded() external {
        vm.warp(10 days + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(ALICE);
        presale.depositETH{value: 2 ether}();
    }

    function test_rejects_whenMinDepositAmount() external {
    }

    function test_rejects_whenExceedUserCap() external {
    }

    function test_emits_Deposit() external {

    }
}

contract PresaleTest_depositUSDC is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotStarted() external {}

    function test_rejects_whenEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_rejects_whenExceedUserCap() external {}

    function test_emits_Deposit() external {}
}

contract PresaleTest_depositDAI is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotStarted() external {}

    function test_rejects_whenEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_rejects_whenExceedUserCap() external {}

    function test_emits_Deposit() external {}
}

contract PresaleTest_receive is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotStarted() external {}

    function test_rejects_whenEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_rejects_whenExceedUserCap() external {}

    function test_emits_Deposit() external {}
}
