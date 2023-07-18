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
        return amount * _round.tokenPrice;
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

            uint256 _roundCostUSD = newRounds[i].tokensAllocated * newRounds[i].tokenPrice;
            _totalCostUSD += _roundCostUSD;
            if (_totalRaisedUSD > _totalCostUSD) {
                _expectedCurrentRoundIndex++;
            }
        }

        $currentRoundIndex = _expectedCurrentRoundIndex;
    }

    function purchase() public payable override whenNotPaused {
        uint256 _amountUSD = ethToUsd(msg.value);

        PurchaseConfig memory _purchaseConfig = PurchaseConfig({
            roundIndex: $currentRoundIndex,
            asset: address(0),
            amountAsset: msg.value,
            amountUSD: _amountUSD,
            account: _msgSender()
        });

        uint256 _purchaseAmountAsset = _sync(_purchaseConfig);
        $config.withdrawTo.transfer(_purchaseAmountAsset);
    }

    function purchase(address account) public payable override whenNotPaused {
        uint256 _amountUSD = ethToUsd(msg.value);

        PurchaseConfig memory _purchaseConfig = PurchaseConfig({
            roundIndex: $currentRoundIndex,
            asset: address(0),
            amountAsset: msg.value,
            amountUSD: _amountUSD,
            account: account
        });

        uint256 _purchaseAmountAsset = _sync(_purchaseConfig);
        $config.withdrawTo.transfer(_purchaseAmountAsset);
    }

    function purchaseUSDC(uint256 amount) external override whenNotPaused {
        address _sender = _msgSender();

        IERC20(USDC).transferFrom(_sender, address(this), amount);

        uint256 _amountScaled = amount * USDC_TO_WEI_PRECISION;

        PurchaseConfig memory _purchaseConfig = PurchaseConfig({
            roundIndex: $currentRoundIndex,
            asset: USDC,
            amountAsset: _amountScaled,
            amountUSD: _amountScaled,
            account: _sender
        });

        uint256 _purchaseAmountAsset = _sync(_purchaseConfig);
        IERC20(USDC).transfer($config.withdrawTo, _purchaseAmountAsset);
    }

    function purchaseDAI(uint256 amount) external override whenNotPaused {
        address _sender = _msgSender();

        IERC20(DAI).transferFrom(_sender, address(this), amount);

        PurchaseConfig memory _purchaseConfig = PurchaseConfig({
            roundIndex: $currentRoundIndex,
            asset: DAI,
            amountAsset: amount,
            amountUSD: amount,
            account: _sender
        });

        uint256 _purchaseAmountAsset = _sync(_purchaseConfig);
        IERC20(DAI).transfer($config.withdrawTo, _purchaseAmountAsset);
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

        uint256 _totalPurchaseAmountAsset;
        uint256 _remainingUSD = purchaseConfig.amountUSD;
        uint256 _userAllocationRemaining = _config.maxUserAllocation - $userTokensAllocated[purchaseConfig.account];

        uint256 _roundAllocationRemaining;


        for (uint256 i = purchaseConfig.roundIndex; i < _rounds.length; ++i) {
            uint256 _currentlyAllocated = $roundAllocated[i];
            _roundAllocationRemaining =
                _currentlyAllocated < _rounds[i].tokensAllocated ? _rounds[i].tokensAllocated - _currentlyAllocated : 0;

            if (_roundAllocationRemaining == 0) continue;

            uint256 _tokensAllocated = _remainingUSD / _rounds[i].tokenPrice;

            if (_tokensAllocated > _roundAllocationRemaining) {
                _tokensAllocated = _roundAllocationRemaining;
            }
            if (_tokensAllocated > _userAllocationRemaining) {
                _tokensAllocated = _userAllocationRemaining;
            }

            if (_tokensAllocated > 0) {
                uint256 _tokensCostUSD = _tokensAllocated * _rounds[i].tokenPrice;

                _remainingUSD -= _tokensCostUSD;
                _roundAllocationRemaining -= _tokensAllocated;
                _userAllocationRemaining -= _tokensAllocated;

                uint256 _roundPurchaseAmountAsset =
                    _tokensCostUSD * purchaseConfig.amountAsset / purchaseConfig.amountUSD;
                _totalPurchaseAmountAsset += _roundPurchaseAmountAsset;

                PurchaseConfig memory _roundPurchaseConfig = PurchaseConfig({
                    roundIndex: i,
                    asset: purchaseConfig.asset,
                    amountAsset: _roundPurchaseAmountAsset,
                    amountUSD: _tokensCostUSD,
                    account: purchaseConfig.account
                });

                _deposit(_roundPurchaseConfig, _tokensAllocated);
            }
        }

        $userTokensAllocated[purchaseConfig.account] = _config.maxUserAllocation - _userAllocationRemaining;

        if (_remainingUSD > 0) {
            _refund(
                purchaseConfig.asset,
                _remainingUSD * purchaseConfig.amountAsset / purchaseConfig.amountUSD,
                _remainingUSD,
                purchaseConfig.account
            );
        }

        return _totalPurchaseAmountAsset;
    }

    function _deposit(PurchaseConfig memory purchaseConfig, uint256 tokensAllocated) private {
        uint256 _roundIndex = purchaseConfig.roundIndex;
        RoundConfig memory _round = $rounds[_roundIndex];

        $roundAllocated[_roundIndex] += tokensAllocated;
        $totalRaisedUSD += purchaseConfig.amountUSD;

        if ($roundAllocated[_roundIndex] == _round.tokensAllocated) {
            $currentRoundIndex++;
        }

        emit Receipt(purchaseConfig, tokensAllocated);
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
}
