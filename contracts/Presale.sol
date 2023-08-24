// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./IPresale.sol";

/**
 * @notice Implementation of the {IPresale} interface.
 */
contract Presale is IPresale, Ownable2Step {
    using Math for uint256;
    using SafeERC20 for IERC20;

    address public immutable override PRESALE_ASSET;
    uint256 public immutable override PRECISION = 1e8;

    uint256 private $currentRoundIndex;
    uint256 private $totalRaised;
    uint256 private $totalPurchases;

    bool private $closed;

    PresaleConfig private $config;
    RoundConfig[] private $rounds;

    mapping(uint256 => uint256) private $roundTokensAllocated;
    mapping(address => uint256) private $userTokensAllocated;
    mapping(address => uint256) private $userLiquidityAllocated;

    constructor(address presaleAsset, PresaleConfig memory newConfig, RoundConfig[] memory newRounds) {
        PRESALE_ASSET = presaleAsset;

        _setConfig(newConfig);
        _setRounds(newRounds);
    }

    /**
     * @inheritdoc IPresale
     */
    function currentRoundIndex() external view override returns (uint256) {
        return $currentRoundIndex;
    }

    /**
     * @inheritdoc IPresale
     */
    function config() external view override returns (PresaleConfig memory) {
        return $config;
    }

    /**
     * @inheritdoc IPresale
     */
    function closed() external view override returns (bool) {
        return $closed;
    }

    /**
     * @inheritdoc IPresale
     */
    function round(uint256 roundIndex) external view override returns (RoundConfig memory) {
        return $rounds[roundIndex];
    }

    /**
     * @inheritdoc IPresale
     */
    function rounds() external view override returns (RoundConfig[] memory) {
        return $rounds;
    }

    /**
     * @inheritdoc IPresale
     */
    function totalPurchases() external view override returns (uint256) {
        return $totalPurchases;
    }

    /**
     * @inheritdoc IPresale
     */
    function totalRounds() external view override returns (uint256) {
        return $rounds.length;
    }

    /**
     * @inheritdoc IPresale
     */
    function totalRaised() external view override returns (uint256) {
        return $totalRaised;
    }

    /**
     * @inheritdoc IPresale
     */
    function roundTokensAllocated(uint256 roundIndex) external view returns (uint256) {
        return $roundTokensAllocated[roundIndex];
    }

    /**
     * @inheritdoc IPresale
     */
    function userTokensAllocated(address account) external view override returns (uint256) {
        return $userTokensAllocated[account];
    }

    /**
     * @inheritdoc IPresale
     */
    function userLiquidityAllocated(address account) external view override returns (uint256) {
        return $userLiquidityAllocated[account];
    }

    /**
     * @inheritdoc IPresale
     */
    function assetsToTokens(uint256 amount, uint256 price) public pure override returns (uint256) {
        return (amount * PRECISION) / price;
    }

    /**
     * @inheritdoc IPresale
     */
    function tokensToAssets(uint256 amount, uint256 price) public pure override returns (uint256) {
        return (amount * price).ceilDiv(PRECISION);
    }

    /**
     * @inheritdoc IPresale
     */
    function close() external override onlyOwner {
        _close();
    }

    /**
     * @inheritdoc IPresale
     */
    function purchase(address account, uint256 amountAsset, bytes memory data)
        external
        override
        returns (Receipt memory)
    {
        return _purchase(PurchaseConfig({amountAsset: amountAsset, account: account, data: data}));
    }

    struct PurchaseCache {
        uint256 totalTokenAllocation;
        uint256 totalLiquidityAllocation;
        uint256 totalRounds;
        uint256 remainingAssets;
        uint256 userAllocationRemaining;
        uint256 currentIndex;
        uint256 roundAllocationRemaining;
        uint256 userAllocation;
    }

    function _purchase(PurchaseConfig memory purchaseConfig) private returns (Receipt memory receipt) {
        PurchaseCache memory _c;
        PresaleConfig memory _config = $config;
        receipt.id = ++$totalPurchases;

        _c.totalRounds = $rounds.length;
        _c.currentIndex = $currentRoundIndex;
        _c.remainingAssets = purchaseConfig.amountAsset;
        _c.userAllocationRemaining = _config.maxUserAllocation - $userTokensAllocated[purchaseConfig.account];

        require(block.timestamp >= _config.startDate, "PRESALE_NOT_STARTED");
        require(!$closed, "PRESALE_CLOSED");
        require(
            purchaseConfig.amountAsset >= _config.minDepositAmount || _config.minDepositAmount == 0,
            "MIN_DEPOSIT_AMOUNT"
        );

        while (_c.currentIndex < _c.totalRounds && _c.remainingAssets > 0 && _c.userAllocationRemaining > 0) {
            RoundConfig memory _round = $rounds[_c.currentIndex];

            _c.roundAllocationRemaining = _remainingRoundAllocation(_c.currentIndex, _round);
            _c.userAllocation = _calculateUserAllocation(_c.remainingAssets, _round);

            if (_c.userAllocation > _c.roundAllocationRemaining) {
                _c.userAllocation = _c.roundAllocationRemaining;
            }
            if (_c.userAllocation > _c.userAllocationRemaining) {
                _c.userAllocation = _c.userAllocationRemaining;
            }

            if (_c.userAllocation > 0) {
                uint256 _costAssets = tokensToAssets(_c.userAllocation, _round.tokenPrice);

                _c.remainingAssets = _subZero(_c.remainingAssets, _costAssets);
                _c.userAllocationRemaining = _subZero(_c.userAllocationRemaining, _c.userAllocation);
                _c.totalTokenAllocation += _c.userAllocation;

                $roundTokensAllocated[_c.currentIndex] += _c.userAllocation;

                if (_round.roundType == RoundType.Liquidity) {
                    _c.totalLiquidityAllocation += _costAssets;
                    _c.remainingAssets = _subZero(_c.remainingAssets, _costAssets);
                }

                emit Purchase(receipt.id, _c.currentIndex, _costAssets, _c.userAllocation);
            }

            // if we have used everything then lets increment current index. and only increment if we are not on the last round.
            if (_c.userAllocation == _c.roundAllocationRemaining) {
                if (_c.currentIndex < _c.totalRounds - 1) {
                    _c.currentIndex++;
                } else {
                    _close();
                }
            } else {
                break;
            }
        }

        unchecked {
            $totalRaised += purchaseConfig.amountAsset - _c.remainingAssets;
            $currentRoundIndex = _c.currentIndex;
            $userTokensAllocated[purchaseConfig.account] = _config.maxUserAllocation - _c.userAllocationRemaining;

            if (_c.totalLiquidityAllocation > 0) {
                $userLiquidityAllocated[purchaseConfig.account] += _c.totalLiquidityAllocation;
            }
        }

        receipt.refundedAssets = _c.remainingAssets;
        receipt.tokensAllocated = _c.totalTokenAllocation;
        receipt.liquidityAssets = _c.totalLiquidityAllocation;
        receipt.costAssets = purchaseConfig.amountAsset - receipt.refundedAssets;

        // edge case to prevent the user from getting free tokens
        require(
            receipt.refundedAssets == 0 || receipt.tokensAllocated == 0
                || receipt.refundedAssets != purchaseConfig.amountAsset,
            "INVALID_PURCHASE"
        );

        if (receipt.refundedAssets > 0) {
            _send(receipt.refundedAssets, purchaseConfig.account);
        }

        if (receipt.costAssets > 0) {
            _send(receipt.costAssets, _config.withdrawTo);
        }

        require(receipt.tokensAllocated > 0, "NO_TOKENS_ALLOCATED");

        emit PurchaseReceipt(receipt.id, purchaseConfig, receipt, _msgSender());
    }

    function _send(uint256 amount, address account) private {
        address _sender = _msgSender();
        if (_sender != account) {
            IERC20(PRESALE_ASSET).safeTransferFrom(_sender, account, amount);
        }
    }

    function _setRounds(RoundConfig[] memory newRounds) private {
        uint256 _totalRounds = $rounds.length;
        for (uint256 i; i < newRounds.length; ++i) {
            if (
                i >= _totalRounds || $roundTokensAllocated[i] < newRounds[i].tokenAllocation
                    || i == newRounds.length - 1
            ) {
                emit RoundsUpdate($rounds, newRounds, $currentRoundIndex, i, _msgSender());
                $currentRoundIndex = i;
                break;
            }
        }

        for (uint256 i; i < _totalRounds; i++) {
            $rounds.pop();
        }

        for (uint256 i; i < newRounds.length; ++i) {
            $rounds.push(newRounds[i]);
        }
    }

    function _setConfig(PresaleConfig memory newConfig) private {
        require(newConfig.startDate > block.timestamp, "INVALID_START_DATE");
        require(newConfig.withdrawTo != address(0), "INVALID_WITHDRAW_TO");

        emit ConfigUpdate($config, newConfig, _msgSender());

        $config = newConfig;
    }

    function _remainingRoundAllocation(uint256 roundIndex, RoundConfig memory round_) private view returns (uint256) {
        uint256 _roundTotalAllocated = $roundTokensAllocated[roundIndex];
        return _subZero(round_.tokenAllocation, _roundTotalAllocated);
    }

    function _calculateUserAllocation(uint256 amountAsset, RoundConfig memory round_) private pure returns (uint256) {
        return
            assetsToTokens(round_.roundType == RoundType.Liquidity ? amountAsset / 2 : amountAsset, round_.tokenPrice);
    }

    function _subZero(uint256 a, uint256 b) private pure returns (uint256) {
        unchecked {
            return a > b ? a - b : 0;
        }
    }

    function _close() private {
        require(!$closed, "PRESALE_ALREADY_CLOSED");
        $closed = true;
        emit Close();
    }
}
