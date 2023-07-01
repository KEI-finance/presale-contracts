// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPresale {
    event DatesUpdated(
        uint256 prevStartsAt, uint256 newStartsAt, uint256 prevEndsAt, uint256 newEndsAt, address indexed sender
    );

    event WithdrawToUpdated(address prevWithdrawTo, address newWithdrawTo, address sender);

    event RoundUpdated(
        uint256 roundIndex, uint256 cap, uint256 userCap, uint256 minDeposit, uint256 maxDeposit, address indexed sender
    );

    event DepositETH(uint8 round, uint256 amount, uint256 amountUSD, address indexed sender);

    event Deposit(uint8 round, address indexed asset, uint256 amountUSD, address indexed sender);

    struct Round {
        uint256 cap;
        uint256 userCap;
        uint256 minDeposit;
        uint256 maxDeposit;
        uint256 totalRaisedUSD;
        mapping(address => uint256) userDeposits;
    }

    function USDC() external pure returns (address);

    function DAI() external pure returns (address);

    function startsAt() external view returns (uint48);

    function endsAt() external view returns (uint48);

    function currentRoundIndex() external view returns (uint256);

    function totalRounds() external view returns (uint256);

    function totalRaisedUSD() external view returns (uint256);

    function totalRaisedInRoundUSD(uint8 roundIndex) external view returns (uint256);

    function updateDates(uint256 newStartsAt, uint256 newEndsAt) external;

    function setWithdrawTo(address payable account) external;

    function updateRoundConfig(uint8 roundId, uint256 minDeposit, uint256 maxDeposit, uint256 cap, uint256 userCap)
        external;

    function depositETH() external payable;

    function depositUSDC(uint256 amount) external;

    function depositDAI(uint256 amount) external;
}
