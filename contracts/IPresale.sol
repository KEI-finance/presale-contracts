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
        uint256 indexed receiptId,
        uint256 indexed roundIndex,
        uint256 amountUSD,
        uint256 tokensAllocated
    );

    event PurchaseReceipt(
        uint256 indexed id,
        PurchaseConfig purchase,
        Receipt receipt,
        address indexed sender
    );

    enum RoundType {
        Liquidity,
        Tokens
    }

    struct PresaleConfig {
        uint128 minDepositAmount;
        uint128 maxUserAllocation;
        uint48 startDate;
        uint48 endDate;
        address withdrawTo;
    }

    struct RoundConfig {
        uint256 tokenPrice;
        uint256 tokenAllocation;
        RoundType roundType;
    }

    struct PurchaseConfig {
        address asset;
        uint256 amountAsset;
        uint256 amountUSD;
        address account;
        bytes data;
    }

    struct Receipt {
        uint256 id;
        uint256 tokensAllocated;
        uint256 refundedAssets;
        uint256 remainingUSD;
        uint256 costAssets;
        uint256 costUSD;
        uint256 usdAllocated;
    }

    function USDC() external view returns (address);

    function DAI() external view returns (address);

    function ORACLE() external view returns (address);

    function PRECISION() external view returns (uint256);

    function USD_PRECISION() external view returns (uint256);

    function USDC_SCALE() external view returns (uint256);

    function currentRoundIndex() external view returns (uint256);

    function config() external view returns (PresaleConfig memory);

    function round(uint256 roundIndex) external view returns (RoundConfig memory);

    function rounds() external view returns (RoundConfig[] memory);

    function totalPurchases() external view returns (uint256);

    function totalRounds() external view returns (uint256);

    function totalRaisedUSD() external view returns (uint256);

    function roundTokensAllocated(uint256 roundIndex) external view returns (uint256);

    function userTokensAllocated(address account) external view returns (uint256);

    function userUSDAllocated(address account) external view returns (uint256);

    function ethPrice() external view returns (uint256);

    function ethToUsd(uint256 amount) external view returns (uint256 _usdAmount);

    function ethToTokens(uint256 amount, uint256 price) external view returns (uint256 _tokenAmount);

    function usdToTokens(uint256 amount, uint256 price) external pure returns (uint256 _tokenAmount);

    function tokensToUSD(uint256 amount, uint256 price) external pure returns (uint256 _usdAmount);

    function pause() external;

    function unpause() external;

    function setConfig(PresaleConfig calldata newConfig) external;

    function setRounds(RoundConfig[] calldata newRounds) external;

    function purchase(address account, bytes memory data) external payable returns (Receipt memory);

    function purchaseUSDC(address account, uint256 amount, bytes calldata data) external returns (Receipt memory);

    function purchaseDAI(address account, uint256 amount, bytes calldata data) external returns (Receipt memory);

    function allocate(address account, uint256 amountUSD, bytes calldata data) external returns (Receipt memory);
}
