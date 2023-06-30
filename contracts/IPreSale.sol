// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPreSale {
    event DatesUpdated(
        uint256 prevStartsAt, uint256 prevEndsAt, uint256 newStartsAt, uint256 newEndsAt, address indexed sender
    );

    event WithdrawToUpdated(address prevWithdrawTo, address newWithdrawTo, address sender);

    event RoundConfigUpdated(RoundConfig prevConfig, RoundConfig newConfig, address indexed sender);

    event Deposit(uint8 round, address indexed asset, uint256 amount, address indexed sender);

    event Withdrawal(uint256 amount, address to, address indexed sender);

    struct RoundConfig {
        uint256 cap; // total deposits before round is closed
        uint256 userCap; // max amount a user can contribute to a round
        uint256 minDeposit; // minimum amount per deposit tx
        uint256 maxDeposit; // maximum amount per deposit tx
    }

    struct Round {
        uint256 startsAt;
        uint256 endsAt;
        uint256 totalRaised;
        RoundConfig config;
        mapping(address => uint256) depositsPerAsset; // asset => depositBalance
        mapping(address => mapping(address => uint256)) deposits; // user => { asset => userDepositBalance }
        mapping(address => uint256) userDeposits; // user => totalDepositBalance
    }

    function startsAt() external view returns (uint256);

    function deadline() external view returns (uint256);

    function currentRound() external view returns (uint8);

    function maxRounds() external view returns (uint8);

    function totalRaised() external view returns (uint256);

    function totalRaisedInRound(uint8 roundId) external view returns (uint256);

    function updateDates(uint256 newStartsAt, uint256 newDeadline) external;

    function setWithdrawTo(address payable account) external;

    function updateRoundConfig(uint8 roundId, uint256 minDeposit, uint256 maxDeposit, uint256 cap, uint256 userCap)
        external;

    function depositETH() external payable;

    function depositUSDC(uint256 amount) external;

    function depositDAI(uint256 amount) external;

    function withdraw() external;
}
