// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPreSale {
    event DatesUpdated(
        uint256 prevStartsAt, uint256 prevEndsAt, uint256 newStartsAt, uint256 newEndsAt, address indexed sender
    );

    event WithdrawToUpdated(address prevWithdrawTo, address newWithdrawTo, address sender);

    event RoundConfigUpdated(uint8 roundId, uint256 minDepositUSD, uint256 maxDepositUSD, address indexed sender);

    event Deposit(address indexed asset, uint256 amount, address indexed sender);

    event Withdrawal(uint256 amount, address to, address indexed sender);

    struct Round {
        uint256 startsAt;
        uint256 endsAt;
        uint256 minDepositUSD;
        uint256 maxDepositUSD;
        mapping(address => mapping(address => uint256)) deposits;
        mapping(address => uint256) totalDepositsPerAsset;
    }

    function totalRaisedUSD() external view returns (uint256);

    function depositETH(uint256 amount) external payable;

    function depositUSDC(uint256 amount) external;

    function depositDAI(uint256 amount) external;

    function withdraw() external;
}
