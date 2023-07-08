// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPresale {
    event DatesUpdated(
        uint256 prevStartsAt, uint256 newStartsAt, uint256 prevEndsAt, uint256 newEndsAt, address indexed sender
    );

    event WithdrawToUpdated(address prevWithdrawTo, address newWithdrawTo, address sender);

    event Withdrawal(address to, uint256 amountUSD, address indexed sender);

    event RoundSet(uint256 roundIndex, Round round, address indexed sender);

    event Deposit(uint256 roundIndex, address indexed asset, uint256 amountUSD, address indexed sender);

    event Refund(address asset, uint256 amountUSD, address indexed sender);

    struct Round {
        uint256 allocationUSD;
        uint256 userCapUSD;
        uint256 minDepositUSD;
        uint256 tokenAllocation;
        uint256 totalRaisedUSD;
    }

    function USDC() external view returns (address);

    function DAI() external view returns (address);

    function startsAt() external view returns (uint48);

    function endsAt() external view returns (uint48);

    function currentRoundIndex() external view returns (uint256);

    function rounds(uint256 roundIndex) external view returns (Round memory);

    function totalRounds() external view returns (uint256);

    function totalRaisedUSD() external view returns (uint256);

    function raisedUSD(uint256 roundIndex) external view returns (uint256);

    function roundDepositsUSD(uint256 roundIndex, address account) external view returns (uint256);

    function roundTokensAllocated(uint256 roundIndex, address account) external view returns (uint256);

    function depositsUSD(address account) external view returns (uint256);

    function tokensAllocated(address account) external view returns (uint256);

    function updateDates(uint48 newStartsAt, uint48 newEndsAt) external;

    function setWithdrawTo(address payable account) external;

    function setRounds(Round[] memory rounds) external;

    function withdraw() external;

    function depositETH() external payable;

    function depositUSDC(uint256 amount) external;

    function depositDAI(uint256 amount) external;
}
