// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPresale {
    event ConfigUpdated(PresaleConfig prevConfig, PresaleConfig newConfig, address indexed sender);

    event RoundsUpdated(RoundConfig[] prevRounds, RoundConfig[] newRounds, address indexed sender);

    event Receipt(
        address indexed asset,
        uint256 indexed roundIndex,
        uint256 tokenPrice,
        uint256 amountAsset,
        uint256 amountUSD,
        uint256 tokensAllocated,
        address indexed sender
    );

    event Refund(address indexed asset, uint256 amountAsset, uint256 amountUSD, address indexed sender);

    struct PresaleConfig {
        uint128 minDepositAmount;
        uint128 maxUserAllocation;
        uint48 startDate;
        uint48 endDate;
        address payable withdrawTo;
    }

    struct RoundConfig {
        uint256 tokenPrice;
        uint256 tokensAllocated;
    }

    struct PurchaseConfig {
        address asset;
        uint256 amountAsset;
        uint256 amountUSD;
        address account;
    }

    function currentRoundIndex() external view returns (uint256);

    function config() external view returns (PresaleConfig memory);

    function round(uint256 roundIndex) external view returns (RoundConfig memory);

    function rounds() external view returns (RoundConfig[] memory);

    function totalRounds() external view returns (uint256);

    function roundAllocated(uint256 roundIndex) external view returns (uint256);

    function totalRaisedUSD() external view returns (uint256);

    function userTokensAllocated(address account) external view returns (uint256);

    function setConfig(PresaleConfig calldata newConfig) external;

    function setRounds(RoundConfig[] calldata newRounds) external;

    function purchase() external payable returns (uint256);

    function purchase(address account) external payable returns (uint256);

    function purchaseUSDC(uint256 amount) external returns (uint256);

    function purchaseDAI(uint256 amount) external returns (uint256);

    function allocate(address account, uint256 amountUSD) external returns (uint256);
}
