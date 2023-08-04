// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./IPresale.sol";

contract Presale is IPresale, Ownable2Step, ReentrancyGuard, Pausable {
    using Math for uint256;

    address public immutable USDC;
    address public immutable DAI;
    AggregatorV3Interface public immutable ORACLE;

    uint256 private immutable PRECISION = 1e8;
    uint256 private immutable USD_PRECISION = 1e18;
    uint256 private immutable USDC_SCALE = 1e12;

    uint256 private $currentRoundIndex;
    uint256 private $totalRaisedUSD;

    PresaleConfig private $config;
    RoundConfig[] private $rounds;

    mapping(uint256 => uint256) private $roundTokensAllocated;
    mapping(address => uint256) private $userTokensAllocated;

    constructor(
        address oracle,
        address usdc,
        address dai,
        PresaleConfig memory newConfig,
        RoundConfig[] memory newRounds
    ) {
        ORACLE = AggregatorV3Interface(oracle);
        USDC = usdc;
        DAI = dai;

        _setConfig(newConfig);
        _setRounds(newRounds);
    }

    function currentRoundIndex() external view returns (uint256) {
        return $currentRoundIndex;
    }

    function config() external view returns (PresaleConfig memory) {
        return $config;
    }

    function round(uint256 roundIndex) external view override returns (RoundConfig memory) {
        return $rounds[roundIndex];
    }

    function rounds() external view override returns (RoundConfig[] memory) {
        return $rounds;
    }

    function totalRounds() external view override returns (uint256) {
        return $rounds.length;
    }

    function totalRaisedUSD() external view override returns (uint256) {
        return $totalRaisedUSD;
    }

    function roundTokensAllocated(uint256 roundIndex) external view returns (uint256) {
        return $roundTokensAllocated[roundIndex];
    }

    function userTokensAllocated(address account) external view override returns (uint256) {
        return $userTokensAllocated[account];
    }

    function ethPrice() public view override returns (uint256) {
        (, int256 price,,,) = ORACLE.latestRoundData();
        return uint256(price);
    }

    function ethToUsd(uint256 amount) public view override returns (uint256 _usdAmount) {
        _usdAmount = (amount * ethPrice()) / PRECISION;
    }

    function ethToTokens(uint256 amount, uint256 price) public view override returns (uint256 _tokenAmount) {
        _tokenAmount = usdToTokens(ethToUsd(amount), price);
    }

    function usdToTokens(uint256 amount, uint256 price) public pure override returns (uint256) {
        return (amount * PRECISION) / price;
    }

    function tokensToUSD(uint256 amount, uint256 price) public pure override returns (uint256) {
        return (amount * price).ceilDiv(PRECISION);
    }

    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    function setConfig(PresaleConfig calldata newConfig) external override onlyOwner {
        _setConfig(newConfig);
    }

    function setRounds(RoundConfig[] calldata newRounds) external override onlyOwner {
        _setRounds(newRounds);
    }

    function purchase() public payable override whenNotPaused returns (uint256 allocation) {
        allocation = purchase(_msgSender());
    }

    function purchase(address account) public payable override whenNotPaused returns (uint256 allocation) {
        uint256 _amountUSD = ethToUsd(msg.value);

        PurchaseConfig memory _purchaseConfig =
            PurchaseConfig({asset: address(0), amountAsset: msg.value, amountUSD: _amountUSD, account: account});

        allocation = _sync(_purchaseConfig);
    }

    function purchaseUSDC(uint256 amount) external override whenNotPaused returns (uint256 allocation) {
        address _sender = _msgSender();

        IERC20(USDC).transferFrom(_sender, address(this), amount);

        uint256 _amountScaled = amount * USDC_SCALE;

        PurchaseConfig memory _purchaseConfig =
            PurchaseConfig({asset: USDC, amountAsset: amount, amountUSD: _amountScaled, account: _sender});

        allocation = _sync(_purchaseConfig);
    }

    function purchaseDAI(uint256 amount) external override whenNotPaused returns (uint256 allocation) {
        address _sender = _msgSender();

        IERC20(DAI).transferFrom(_sender, address(this), amount);

        PurchaseConfig memory _purchaseConfig =
            PurchaseConfig({asset: DAI, amountAsset: amount, amountUSD: amount, account: _sender});

        allocation = _sync(_purchaseConfig);
    }

    function allocate(address account, uint256 amountUSD) external override onlyOwner returns (uint256 allocation) {
        PurchaseConfig memory _purchaseConfig =
            PurchaseConfig({asset: address(0), amountAsset: 0, amountUSD: amountUSD, account: account});

        allocation = _sync(_purchaseConfig);
    }

    receive() external payable {
        purchase();
    }

    struct SyncCache {
        uint256 totalAllocation;
        uint256 totalCostAsset;
        uint256 totalRounds;
        uint256 remainingUSD;
        uint256 userAllocationRemaining;
        uint256 currentIndex;
    }

    function _sync(PurchaseConfig memory purchaseConfig) private returns (uint256) {
        PresaleConfig memory _config = $config;

        require(block.timestamp >= _config.startDate, "RAISE_NOT_STARTED");
        require(block.timestamp <= _config.endDate, "RAISE_ENDED");
        require(
            purchaseConfig.amountUSD >= _config.minDepositAmount || _config.minDepositAmount == 0, "MIN_DEPOSIT_AMOUNT"
        );

        SyncCache memory _c;

        _c.totalRounds = $rounds.length;
        _c.currentIndex = $currentRoundIndex;
        _c.remainingUSD = purchaseConfig.amountUSD;
        _c.userAllocationRemaining = _config.maxUserAllocation - $userTokensAllocated[purchaseConfig.account];

        while (_c.currentIndex < _c.totalRounds && _c.remainingUSD > 0 && _c.userAllocationRemaining > 0) {
            RoundConfig memory _round = $rounds[_c.currentIndex];
            uint256 _roundTotalAllocated = $roundTokensAllocated[_c.currentIndex];
            uint256 _roundAllocationRemaining =
                _roundTotalAllocated < _round.tokensAllocated ? _round.tokensAllocated - _roundTotalAllocated : 0;

            uint256 _userAllocation = usdToTokens(_c.remainingUSD, _round.tokenPrice);

            if (_userAllocation > _roundAllocationRemaining) {
                _userAllocation = _roundAllocationRemaining;
            }
            if (_userAllocation > _c.userAllocationRemaining) {
                _userAllocation = _c.userAllocationRemaining;
            }

            if (_userAllocation > 0) {
                uint256 _tokensCostUSD = tokensToUSD(_userAllocation, _round.tokenPrice);
                uint256 _roundPurchaseAmountAsset = (_tokensCostUSD * purchaseConfig.amountAsset) / purchaseConfig.amountUSD;

                _c.remainingUSD -= _tokensCostUSD;
                _c.userAllocationRemaining -= _userAllocation;
                _c.totalAllocation += _userAllocation;
                _c.totalCostAsset += _roundPurchaseAmountAsset;

                $roundTokensAllocated[_c.currentIndex] += _userAllocation;
                $totalRaisedUSD += _tokensCostUSD;

                emit Purchase(
                    purchaseConfig.asset,
                    _c.currentIndex,
                    _round.tokenPrice,
                    _roundPurchaseAmountAsset,
                    _tokensCostUSD,
                    _userAllocation,
                    purchaseConfig.account
                );
            }

            // if we have used everything then lets increment current index. and only increment if we are not on the last round.
            if (_userAllocation == _roundAllocationRemaining && _c.currentIndex < _c.totalRounds - 1) {
                _c.currentIndex++;
            } else {
                break;
            }
        }

        $currentRoundIndex = _c.currentIndex;
        $userTokensAllocated[purchaseConfig.account] = _config.maxUserAllocation - _c.userAllocationRemaining;

        // for when we are dealing with ceil div of more than the amount required.
        if (_c.totalCostAsset > purchaseConfig.amountAsset) _c.totalCostAsset = purchaseConfig.amountAsset;

        // how much did we not allocate? and therefore need to refund.
        uint256 _refundAmountAsset = purchaseConfig.amountAsset - _c.totalCostAsset;

        // edge case to prevent the user from getting free tokens
        require(
            _refundAmountAsset == 0 ||
            _c.totalAllocation == 0 ||
            _refundAmountAsset != purchaseConfig.amountAsset,
            'INVALID_PURCHASE'
        );

        if (_refundAmountAsset > 0) {
            _send(purchaseConfig.asset, _refundAmountAsset, payable(purchaseConfig.account));
            emit Refund(purchaseConfig.asset, _refundAmountAsset, _c.remainingUSD, purchaseConfig.account);
        }

        if (_c.totalCostAsset > 0) {
            _send(purchaseConfig.asset, _c.totalCostAsset, _config.withdrawTo);
        }

        return _c.totalAllocation;
    }

    function _send(address asset, uint256 amountAsset, address payable account) private {
        if (asset == address(0)) {
            account.transfer(amountAsset);
        } else {
            IERC20(asset).transfer(account, amountAsset);
        }
    }

    function _setRounds(RoundConfig[] memory newRounds) private {

        uint256 _totalRounds = $rounds.length;
        for (uint256 i; i < newRounds.length; ++i) {
            if (i >= _totalRounds || $roundTokensAllocated[i] < newRounds[i].tokensAllocated || i == newRounds.length - 1) {
                emit RoundsUpdated($rounds, newRounds, $currentRoundIndex, i, _msgSender());
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
        require(newConfig.startDate < newConfig.endDate, "INVALID_DATES");
        require(newConfig.withdrawTo != address(0), "INVALID_WITHDRAW_TO");

        emit ConfigUpdated($config, newConfig, _msgSender());

        $config = newConfig;
    }
}
