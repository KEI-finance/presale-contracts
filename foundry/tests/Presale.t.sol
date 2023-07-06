// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "forge-std/Test.sol";

import "contracts/PreSale.sol";

import "../mocks/TestERC20.sol";

contract PresaleTest is Test {
    Presale internal presale;

    address payable internal GLOBAL_ADMIN;

    address internal ALICE;
    address internal BOB;

    uint48 internal startsAt;
    uint48 internal endsAt;

    IPresale.Round[] internal rounds;

    function setUp() public virtual {
        GLOBAL_ADMIN = payable(makeAddr("GLOBAL_ADMIN"));
        ALICE = makeAddr("ALICE");
        BOB = makeAddr("BOB");

        startsAt = 1 days;
        endsAt = 10 days;

        vm.prank(GLOBAL_ADMIN);
        presale = new Presale(startsAt, endsAt, GLOBAL_ADMIN);
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
    function test_success() external {}
}

contract PresaleTest_totalRaisedUSD is PresaleTest {
    function test_success() external {}
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
    function test_success() external {}
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
        
    }
}

contract PresaleTest_depositETH is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotStarted() external {}

    function test_rejects_whenEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_rejects_whenExceedUserCap() external {}

    function test_emits_Deposit() external {}
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





















