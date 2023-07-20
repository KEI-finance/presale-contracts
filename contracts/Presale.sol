// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IPresale.sol";

contract Presale is IPresale, Ownable2Step, ReentrancyGuard, Pausable {
    address public immutable USDC;

    address public immutable DAI;

    AggregatorV3Interface public immutable ORACLE;

    uint256 private immutable PRECISION = 1e18;
    uint256 private immutable ETH_TO_WEI_PRECISION = 1e10;
    uint256 private immutable USDC_TO_WEI_PRECISION = 1e12;

    uint256 private $currentRoundIndex;
    uint256 private $totalRaisedUSD;

    PresaleConfig private $config;
    RoundConfig[] private $rounds;

    mapping(uint256 => uint256) private $roundAllocated;
    mapping(address => uint256) private $userTokensAllocated;

    constructor(address oracle, address usdc, address dai, PresaleConfig memory config_) {
        ORACLE = AggregatorV3Interface(oracle);
        USDC = usdc;
        DAI = dai;

        $config = config_;
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

    function roundAllocated(uint256 roundIndex) external view returns (uint256) {
        return $roundAllocated[roundIndex];
    }

    function totalRaisedUSD() external view override returns (uint256) {
        return $totalRaisedUSD;
    }

    function userTokensAllocated(address account) external view override returns (uint256) {
        return $userTokensAllocated[account];
    }

    function ethPrice() public view returns (uint256) {
        (, int256 price,,,) = ORACLE.latestRoundData();
        return uint256(uint256(price) * ETH_TO_WEI_PRECISION);
    }

    function ethToUsd(uint256 amount) public view returns (uint256) {
        uint256 _ethPrice = ethPrice();
        uint256 _ethAmountInUsd = (_ethPrice * amount) / PRECISION;
        return _ethAmountInUsd;
    }

    function usdToTokens(uint256 roundIndex, uint256 amount) public view returns (uint256) {
        RoundConfig memory _round = $rounds[roundIndex];
        return amount * _round.tokenPrice / PRECISION;
    }

    function setConfig(PresaleConfig calldata newConfig) external override onlyOwner {
        require(newConfig.startDate < newConfig.endDate, "INVALID_DATES");
        require(newConfig.withdrawTo != address(0), "INVALID_WITHDRAW_TO");

        emit ConfigUpdated($config, newConfig, _msgSender());

        $config = newConfig;
    }

    function setRounds(RoundConfig[] calldata newRounds) external override onlyOwner {
        emit RoundsUpdated($rounds, newRounds, _msgSender());

        for (uint256 i; i < $rounds.length; ++i) {
            $rounds.pop();
        }

        uint256 _totalCostUSD;
        uint256 _totalRaisedUSD = $totalRaisedUSD;
        uint256 _expectedCurrentRoundIndex;

        for (uint256 i; i < newRounds.length; ++i) {
            $rounds.push(newRounds[i]);

            uint256 _roundCostUSD = newRounds[i].tokensAllocated * newRounds[i].tokenPrice / PRECISION;
            _totalCostUSD += _roundCostUSD;
            if (_totalRaisedUSD > _totalCostUSD) {
                _expectedCurrentRoundIndex++;
            }
        }

        $currentRoundIndex = _expectedCurrentRoundIndex;
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

        uint256 _amountScaled = amount * USDC_TO_WEI_PRECISION;

        PurchaseConfig memory _purchaseConfig =
            PurchaseConfig({asset: USDC, amountAsset: _amountScaled, amountUSD: _amountScaled, account: _sender});

        allocation = _sync(_purchaseConfig);
    }

    function purchaseDAI(uint256 amount) external override whenNotPaused returns (uint256 allocation) {
        address _sender = _msgSender();

        IERC20(DAI).transferFrom(_sender, address(this), amount);

        PurchaseConfig memory _purchaseConfig =
            PurchaseConfig({asset: DAI, amountAsset: amount, amountUSD: amount, account: _sender});

        allocation = _sync(_purchaseConfig);
    }

    receive() external payable {
        purchase();
    }

    function _sync(PurchaseConfig memory purchaseConfig) private returns (uint256) {
        PresaleConfig memory _config = $config;
        RoundConfig[] memory _rounds = $rounds;

        require(block.timestamp >= _config.startDate, "RAISE_NOT_STARTED");
        require(block.timestamp <= _config.endDate, "RAISE_ENDED");
        require(
            purchaseConfig.amountUSD >= _config.minDepositAmount || _config.minDepositAmount == 0, "MIN_DEPOSIT_AMOUNT"
        );

        uint256 _totalAllocation;
        uint256 _totalPurchaseAmountAsset;

        uint256 _remainingUSD = purchaseConfig.amountUSD;
        uint256 _userAllocationRemaining = _config.maxUserAllocation - $userTokensAllocated[purchaseConfig.account];

        uint256 i = $currentRoundIndex;
        for (i; i < _rounds.length && _remainingUSD > 0 && _userAllocationRemaining > 0; ++i) {
            uint256 _roundAllocated = $roundAllocated[i];
            uint256 _roundAllocationRemaining =
                _roundAllocated < _rounds[i].tokensAllocated ? _rounds[i].tokensAllocated - _roundAllocated : 0;

            if (_roundAllocationRemaining == 0) continue;

            uint256 _roundAllocation = _remainingUSD * PRECISION / _rounds[i].tokenPrice;

            if (_roundAllocation > _roundAllocationRemaining) {
                _roundAllocation = _roundAllocationRemaining;
            }
            if (_roundAllocation > _userAllocationRemaining) {
                _roundAllocation = _userAllocationRemaining;
            }

            require(_roundAllocation > 0, "MIN_ALLOCATION");

            uint256 _tokensCostUSD = _roundAllocation * _rounds[i].tokenPrice / PRECISION;
            _remainingUSD -= _tokensCostUSD;

            _userAllocationRemaining -= _roundAllocation;
            _totalAllocation += _roundAllocation;

            uint256 _roundPurchaseAmountAsset = _tokensCostUSD * purchaseConfig.amountAsset / purchaseConfig.amountUSD;
            _totalPurchaseAmountAsset += _roundPurchaseAmountAsset;

            PurchaseConfig memory _roundPurchaseConfig;
            _roundPurchaseConfig.asset = purchaseConfig.asset;
            _roundPurchaseConfig.amountAsset = _roundPurchaseAmountAsset;
            _roundPurchaseConfig.amountUSD = _tokensCostUSD;
            _roundPurchaseConfig.account = purchaseConfig.account;

            _deposit(i, _rounds[i], _roundPurchaseConfig, _roundAllocation);

            $currentRoundIndex = i;
        }

        $userTokensAllocated[purchaseConfig.account] = _config.maxUserAllocation - _userAllocationRemaining;

        uint256 _refundAmountAsset = purchaseConfig.amountAsset - _totalPurchaseAmountAsset;
        if (_refundAmountAsset > 0) {
            _refund(purchaseConfig.asset, _refundAmountAsset, _remainingUSD, purchaseConfig.account);
        }

        if (_totalPurchaseAmountAsset > 0) {
            _forwardToWithdrawTo(purchaseConfig.asset, _totalPurchaseAmountAsset);
        }

        return _totalAllocation;
    }

    function _deposit(
        uint256 roundIndex,
        RoundConfig memory roundConfig,
        PurchaseConfig memory roundPurchaseConfig,
        uint256 tokensAllocated
    ) private {
        $roundAllocated[roundIndex] += tokensAllocated;
        $totalRaisedUSD += roundPurchaseConfig.amountUSD;

        emit Receipt(
            roundIndex,
            roundConfig.tokenPrice,
            roundPurchaseConfig.asset,
            roundPurchaseConfig.amountAsset,
            roundPurchaseConfig.amountUSD,
            tokensAllocated,
            roundPurchaseConfig.account
        );
    }

    function _refund(address asset, uint256 amountAsset, uint256 amountUSD, address account) private {
        if (asset == USDC) {
            IERC20(USDC).transfer(account, amountUSD / USDC_TO_WEI_PRECISION);
        } else if (asset == DAI) {
            IERC20(DAI).transfer(account, amountUSD);
        } else {
            uint256 amountInWei = amountUSD * PRECISION / ethPrice();
            payable(account).transfer(amountInWei);
        }

        emit Refund(asset, amountAsset, amountUSD, account);
    }

    function _forwardToWithdrawTo(address asset, uint256 amountAsset) private {
        address payable _withdrawTo = $config.withdrawTo;

        if (asset == address(0)) {
            _withdrawTo.transfer(amountAsset);
        } else {
            IERC20(asset).transfer(_withdrawTo, amountAsset);
        }
    }
}
