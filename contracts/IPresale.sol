// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

interface IPresale {
    event ConfigUpdated(PresaleConfig prevConfig, PresaleConfig newConfig, address indexed sender);

    event RoundsUpdated(
        RoundConfig[] prevRounds,
        RoundConfig[] newRounds,
        uint256 prevCurrentRoundIndex,
        uint256 newCurrentRoundIndex,
        address indexed sender
    );

    event Purchase(
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

    function totalRaisedUSD() external view returns (uint256);

    function roundTokensAllocated(uint256 roundIndex) external view returns (uint256);

    function userTokensAllocated(address account) external view returns (uint256);

    function ethPrice() external view returns (uint256);

    function ethToUsd(uint256 amount) external view returns (uint256 _usdAmount);

    function ethToTokens(uint256 amount, uint256 price) external view returns (uint256 _tokenAmount);

    function usdToTokens(uint256 amount, uint256 price) external pure returns (uint256 _tokenAmount);

    function tokensToUSD(uint256 amount, uint256 price) external pure returns (uint256 _usdAmount);

    function pause() external;

    function unpause() external;

    function setConfig(PresaleConfig calldata newConfig) external;

    function setRounds(RoundConfig[] calldata newRounds) external;

    function purchase() external payable returns (uint256 allocation);

    function purchase(address account) external payable returns (uint256 allocation);

    function purchaseUSDC(uint256 amount) external returns (uint256 allocation);

    function purchaseDAI(uint256 amount) external returns (uint256 allocation);

    function allocate(address account, uint256 amountUSD) external returns (uint256 allocation);
}
