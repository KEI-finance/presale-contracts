// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

/**
 * @title KEI Finance Presale Contract.
 * @author KEI Finance
 * @notice A fund raising contract for liquidity pools or initial token offering.
 */
interface IPresale {
    /**
     * @notice Emitted when the {PresaleConfig} is updated.
     * @param prevConfig The previous presale configuration.
     * @param newConfig The new presale configuration.
     * @param sender The message sender that triggered the event.
     */
    event ConfigUpdate(PresaleConfig prevConfig, PresaleConfig newConfig, address indexed sender);

    /**
     * @notice Emitted when the {RoundConfig} array is updated.
     * @param prevRounds The previous array of round configurations.
     * @param newRounds The previous array of round configurations.
     * @param prevCurrentRoundIndex The previous current round index.
     * @param newCurrentRoundIndex The new current round index.
     * @param sender The message sender that triggered the event.
     */
    event RoundsUpdate(
        RoundConfig[] prevRounds,
        RoundConfig[] newRounds,
        uint256 prevCurrentRoundIndex,
        uint256 newCurrentRoundIndex,
        address indexed sender
    );

    /**
     * @notice Emitted when the presale has either finished or manually been closed
     */
    event Close();

    /**
     * @notice Emitted when a purchase in a round is made.
     * @param receiptId The ID of the receipt that this purchase is tied to.
     * @param roundIndex The round index that the purchase was made in.
     * @param amountAsset The assets value of the tokens purchased.
     * @param tokensAllocated The number of tokens allocated to the purchaser.
     */
    event Purchase(uint256 indexed receiptId, uint256 indexed roundIndex, uint256 amountAsset, uint256 tokensAllocated);

    /**
     * @notice Emitted when a purchase is made.
     * @param id The receipt ID.
     * @param purchase The purchase configuration.
     * @param receipt The receipt details.
     * @param sender The message sender that triggered the event.
     */
    event PurchaseReceipt(uint256 indexed id, PurchaseConfig purchase, Receipt receipt, address indexed sender);

    /**
     * @notice Round type - either for liquidity pool provision or for initial token issuance.
     */
    enum RoundType {
        Liquidity,
        Tokens
    }

    /**
     * @notice Presale Configuration structure.
     * @param minDepositAmount The minimum amount of assets to purchase with.
     * @param maxUserAllocation The maximum number of tokens a user can purchase across all rounds.
     * @param startDate The unix timestamp marking the start of the presale.
     * @param endDate The unix timestamp marking the end of the presale.
     * @param withdrawTo The address that immediately receives all funds on each purchase.
     */
    struct PresaleConfig {
        uint128 minDepositAmount;
        uint128 maxUserAllocation;
        uint48 startDate;
        address withdrawTo;
    }

    /**
     * @notice Round Configuration structure.
     * @param tokenPrice The round token price.
     * @param tokenAllocation The number of tokens allocated for purchase in the round.
     * @param roundType The type of the round.
     */
    struct RoundConfig {
        uint256 tokenPrice;
        uint256 tokenAllocation;
        RoundType roundType;
    }

    /**
     * @notice Purchase Configuration structure.
     * @param amountAsset The amount of the asset the user intends to spend.
     * @param account The account that will be be allocated tokens.
     * @param data Additional bytes data tied to the purchase.
     */
    struct PurchaseConfig {
        uint256 amountAsset;
        address account;
        bytes data;
    }

    /**
     * @notice Receipt structure.
     * @param id The receipt ID.
     * @param tokensAllocated The number of tokens allocated.
     * @param refundedAssets The number of tokens refunded.
     * @param costAssets The number of assets spent.
     * @param allocatedAssets The number of assets allocated to liquidity.
     */
    struct Receipt {
        uint256 id;
        uint256 tokensAllocated;
        uint256 refundedAssets;
        uint256 costAssets;
        uint256 liquidityAssets;
    }

    /**
     * @notice The PRESALE_ASSET used for purchasing the KEI tokens
     */
    function PRESALE_ASSET() external view returns (address);

    /**
     * @notice The 8 decimal precision used in the contract.
     */
    function PRECISION() external view returns (uint256);

    /**
     * @notice Returns the current round index.
     */
    function currentRoundIndex() external view returns (uint256);

    /**
     * @notice Returns the presale configuration.
     */
    function config() external view returns (PresaleConfig memory);

    /**
     * @notice Returns whether or not the presale has ended
     */
    function closed() external view returns (bool);

    /**
     * @notice Returns the configuration of a specific round.
     * @param roundIndex The round index to return the configuration of.
     */
    function round(uint256 roundIndex) external view returns (RoundConfig memory);

    /**
     * @notice Returns an array of all the round configurations set by the admin.
     */
    function rounds() external view returns (RoundConfig[] memory);

    /**
     * @notice Returns the number of total purchases made.
     */
    function totalPurchases() external view returns (uint256);

    /**
     * @notice Returns the number of total rounds.
     */
    function totalRounds() external view returns (uint256);

    /**
     * @notice Returns the total amount of presale assets raised
     */
    function totalRaised() external view returns (uint256);

    /**
     * @notice Returns the number of tokens allocated in a round.
     * @param roundIndex The index of the round to return the tokens allocated in.
     */
    function roundTokensAllocated(uint256 roundIndex) external view returns (uint256);

    /**
     * @notice Returns the number of tokens allocated to a specific user across `Token` type rounds.
     * @param account The account to return the token allocation of.
     */
    function userTokensAllocated(address account) external view returns (uint256);

    /**
     * @notice Returns the amount of PRESALE_ASSETs a user has allocated to liquidity provision balance of a user across all `Liquidity` type rounds.
     * @param account The account to query
     */
    function userLiquidityAllocated(address account) external view returns (uint256);

    /**
     * @notice Returns the conversion from assets to tokens. Where assets is the PRESALE_ASSET
     * @param amount The amount of assets to convert.
     * @param price The price of tokens - based on the current round price set by admin.
     * @return tokenAmount The number of tokens that are equal to the value of input assets.
     */
    function assetsToTokens(uint256 amount, uint256 price) external pure returns (uint256 tokenAmount);

    /**
     * @notice Returns the conversion from tokens to assets.
     * @param amount The amount of tokens to convert.
     * @param price The price of tokens - based on the current round price set by admin.
     * @return amountAsset The assets value of the input tokens.
     */
    function tokensToAssets(uint256 amount, uint256 price) external pure returns (uint256 amountAsset);

    /**
     * @notice Closes the Presale early, before all the rounds have been complete
     * @custom:emits Close
     * @custom:requirement The function caller must be the owner of the contract.
     * @custom:requirement The contract must not already be closed.
     */
    function close() external;

    /**
     * @notice Purchases tokens for `account` or increases a user's liquidity provision balance, by spending DAI - depending on the round type.
     * @param account The account to be allocated the purchased tokens or increased liquidity provision balance.
     * @param amountAsset The amount of assets intended to be spent.
     * @param data Additional bytes data tied to the purchase.
     * @custom:emits Purchase - for each round that the purchase is made within
     * @custom:emits PurchaseReceipt
     * @custom:requirement The contract must not be paused.
     * @custom:requirement The current block timestamp must be grater or equal to the presale configuration `startDate`.
     * @custom:requirement The current block timestamp must be less than or equal to the presale configuration `endDate`.
     * @custom:requirement The asset value of the intended purchase amount must be greater than zero or the presale configuration minimum deposit amount is equal to zero.
     * @custom:requirement Either the refunded purchase asset amount or tokens allocated must be equal to zero, or the refunded purchase asset amount is not equal to the
     * intended purchase asset amount.
     * @custom:requirement The number of tokens allocated to `account` must be greater than zero.
     * @return The receipt.
     */
    function purchase(address account, uint256 amountAsset, bytes calldata data) external returns (Receipt memory);
}
