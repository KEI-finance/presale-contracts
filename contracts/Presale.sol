// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IPresale.sol";

import "forge-std/console.sol";

contract Presale is IPresale, Ownable2Step, ReentrancyGuard, Pausable {
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
        return uint256(price);
    }

    function ethToUsd(uint256 amount) public view returns (uint256 _usdAmount) {
        _usdAmount = (amount * ethPrice()) / PRECISION;
    }

    function usdToTokens(uint256 roundIndex, uint256 amount) public view returns (uint256) {
        RoundConfig memory _round = $rounds[roundIndex];
        return amount * _round.tokenPrice / USD_PRECISION;
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

        address _asset = purchaseConfig.asset;
        uint256 _amountAsset = purchaseConfig.amountAsset;
        uint256 _amountUSD = purchaseConfig.amountUSD;
        address _account = purchaseConfig.account;

        uint256 _remainingUSD = purchaseConfig.amountUSD;
        uint256 _userAllocationRemaining = _config.maxUserAllocation - $userTokensAllocated[_account];

        uint256 i = $currentRoundIndex;
        for (i; i < _rounds.length && _remainingUSD > 0 && _userAllocationRemaining > 0; ++i) {
            RoundConfig memory _round = _rounds[i];
            uint256 _roundAllocated = $roundAllocated[i];
            uint256 _roundAllocationRemaining =
                _roundAllocated < _round.tokensAllocated ? _round.tokensAllocated - _roundAllocated : 0;

            if (_roundAllocationRemaining == 0) continue;

            uint256 _roundAllocation = (_remainingUSD * PRECISION) / _round.tokenPrice;

            if (_roundAllocation > _roundAllocationRemaining) {
                _roundAllocation = _roundAllocationRemaining;
            }
            if (_roundAllocation > _userAllocationRemaining) {
                _roundAllocation = _userAllocationRemaining;
            }

            console.log('round', i);
            console.log("_roundAllocation", _roundAllocation);
            console.log("_remainingUSD", _remainingUSD);
            console.log("_roundAllocationRemaining", _roundAllocationRemaining);
            console.log("_userAllocationRemaining", _userAllocationRemaining);

            if (_roundAllocation == 0) {
                break;
            }

            uint256 _tokensCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            console.log(_tokensCostUSD);
            _remainingUSD -= _tokensCostUSD;

            _userAllocationRemaining -= _roundAllocation;
            _totalAllocation += _roundAllocation;

            uint256 _roundPurchaseAmountAsset = _tokensCostUSD * _amountAsset / _amountUSD;
            _totalPurchaseAmountAsset += _roundPurchaseAmountAsset;

            $roundAllocated[i] += _roundAllocation;
            $totalRaisedUSD += _tokensCostUSD;

            emit Receipt(
                _asset, i, _round.tokenPrice, _roundPurchaseAmountAsset, _tokensCostUSD, _roundAllocation, _account
            );
        }

        require(_totalAllocation > 0, "MIN_ALLOCATION");

        $currentRoundIndex = i;

        $userTokensAllocated[_account] = _config.maxUserAllocation - _userAllocationRemaining;

        uint256 _refundAmountAsset = _amountAsset - _totalPurchaseAmountAsset;

        if (_refundAmountAsset > 0) {
            _send(_asset, _refundAmountAsset, payable(_account));
            emit Refund(_asset, _refundAmountAsset, _remainingUSD, _account);
        }

        if (_totalPurchaseAmountAsset > 0) {
            _send(_asset, _totalPurchaseAmountAsset, _config.withdrawTo);
        }

        return _totalAllocation;
    }

    function _send(address asset, uint256 amountAsset, address payable account) private {
        if (asset == address(0)) {
            account.transfer(amountAsset);
        } else {
            IERC20(asset).transfer(account, amountAsset);
        }
    }
}
