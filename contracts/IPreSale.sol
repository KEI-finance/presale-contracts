// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPreSale {
    event DeadlineUpdated(uint256 prevDeadline, uint256 newDeadline, address indexed sender);

    event Deposit(uint256 amount, address indexed sender);

    event Withdrawal(uint256 amount, address to, address indexed sender);

    event Refund(uint256 amount, address indexed sender);

    function totalRaised() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function raiseDeadline() external view returns (uint256);

    function setRaiseDeadline(uint256 newDeadline) external;

    function withdraw(address payable to) external;

    function refund(address payable to) external;
}
