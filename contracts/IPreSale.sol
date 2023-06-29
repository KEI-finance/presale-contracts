// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPreSale {
    event DatesUpdated(
        uint256 prevStartsAt, uint256 prevEndsAt, uint256 newStartsAt, uint256 newEndsAt, address indexed sender
    );

    event WithdrawToUpdated(address prevWithdrawTo, address newWithdrawTo, address sender);

    event Deposit(uint256 amount, address indexed sender);

    event Withdrawal(uint256 amount, address to, address indexed sender);

    struct Contribution {
        address asset;
        uint256 amount;
        address sender;
    }

    struct Round {
        uint8 id;
        uint256 startsAt;
        uint256 endsAt;
        mapping(address => uint256) assetsRaised;
        Contribution[] contributions;
    }

    function withdraw() external;
}
