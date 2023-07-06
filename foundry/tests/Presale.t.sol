// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "forge-std/Test.sol";

import "contracts/PreSale.sol";

import "../mocks/TestERC20.sol";

contract PresaleTest {
    function setUp() public virtual {}
}

contract PresaleTest_startsAt is PresaleTest {
    function test_success() external {}
}

contract PresaleTest_endsAt is PresaleTest {
    function test_success() external {}
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
    function test_success() external {}

    function test_rejects_whenNotOwner() external {}

    function test_emits_DatesUpdated() external {}
}

contract PresaleTest_setWithdrawTo is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotOwner() external {}

    function test_rejects_whenAddressZero() external {}

    function test_emits_WithdrawToUpdated() external {}
}

contract PresaleTest_setRounds is PresaleTest {
    function test_success() external {}

    function test_rejects_whenNotOwner() external {}

    function test_emits_RoundSet() external {}
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





















