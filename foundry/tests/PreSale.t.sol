// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "forge-std/Test.sol";

import "contracts/PreSale.sol";

import "../mocks/TestERC20.sol";

contract PreSaleTest is Test {
    PreSale internal preSale;

    address ALICE;
    address BOB;

    function setUp() public {
        preSale = new PreSale();

        assertEq(preSale.owner(), address(this));

        ALICE = makeAddr("ALICE");
        BOB = makeAddr("BOB");

        vm.deal(ALICE, 100 ether);
        vm.deal(BOB, 100 ether);

        bool _success;

        vm.prank(ALICE);
        (_success,) = address(preSale).call{value: 10 ether}("");
        assertTrue(_success);
        assertEq(preSale.totalRaised(), 10 ether);

        vm.prank(BOB);
        (_success,) = address(preSale).call{value: 10 ether}("");
        assertTrue(_success);
        assertEq(preSale.totalRaised(), 20 ether);
    }

    receive() external payable {}
}

contract PreSaleTest_balanceOf is PreSaleTest {
    function test_success() external {
        assertEq(preSale.balanceOf(ALICE), 10 ether);
        assertEq(preSale.balanceOf(BOB), 10 ether);
    }
}

contract PreSaleTest_receive is PreSaleTest {
    event Deposit(uint256 amount, address indexed sender);

    function test_success() external {
        bool _success;

        vm.prank(ALICE);
        (_success,) = address(preSale).call{value: 10 ether}("");
        assertTrue(_success);

        vm.prank(BOB);
        (_success,) = address(preSale).call{value: 10 ether}("");
        assertTrue(_success);

        assertEq(ALICE.balance, 80 ether);
        assertEq(BOB.balance, 80 ether);
        assertEq(preSale.totalRaised(), 40 ether);
    }

    function test_emits_Deposit() external {
        vm.expectEmit(address(preSale));
        emit Deposit(10 ether, ALICE);

        vm.prank(ALICE);
        (bool success,) = address(preSale).call{value: 10 ether}("");
        assertTrue(success);
    }
}

contract PreSaleTest_withdraw is PreSaleTest {
    event Withdrawal(uint256 amount, address to, address indexed sender);

    function test_success() external {
        uint256 _prevETHBalance = address(this).balance;

        uint256 _totalRaised = preSale.totalRaised();

        preSale.withdraw(payable(address(this)));
        assertEq(address(this).balance, _prevETHBalance + _totalRaised);
        assertEq(address(preSale).balance, 0);
    }

    function test_rejects_whenTransferFailed() external {
        TestERC20 _erc20 = new TestERC20("TEST", "TEST");

        vm.expectRevert("FAILED_WITHDRAW");
        preSale.withdraw(payable(address(_erc20)));
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        preSale.withdraw(payable(address(ALICE)));
    }

    function test_emits_Withdrawal() external {
        vm.expectEmit(address(preSale));
        emit Withdrawal(20 ether, address(this), address(this));

        preSale.withdraw(payable(address(this)));
    }
}

contract PreSaleTest_refund is PreSaleTest {
    event Refund(uint256 amount, address indexed sender);

    function test_success() external {
        vm.prank(ALICE);
        preSale.refund(payable(ALICE));

        assertEq(ALICE.balance, 100 ether);

        vm.prank(BOB);
        preSale.refund(payable(BOB));

        assertEq(BOB.balance, 100 ether);

        assertEq(preSale.totalRaised(), 0);
    }

    function test_rejects_whenTransferFailed() external {
        TestERC20 _erc20 = new TestERC20("TEST", "TEST");

        vm.expectRevert("FAILED_REFUND");

        vm.prank(payable(ALICE));
        preSale.refund(payable(address(_erc20)));
    }

    function test_rejects_whenZeroBalance() external {
        address _invalidAddress = makeAddr("invalidAddress");

        vm.expectRevert("ZERO_BALANCE");
        preSale.refund(payable(address(_invalidAddress)));
    }

    function test_emits_Refund() external {
        vm.expectEmit(address(preSale));
        emit Refund(10 ether, ALICE);

        vm.prank(ALICE);
        preSale.refund(payable(ALICE));
    }
}
