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

    address payable public $withdrawTo;

    mapping(uint256 => uint256) private $raisedUSD;
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

    function raisedUSD(uint256 roundIndex) external view returns (uint256) {
        return $raisedUSD[roundIndex];
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
        emit ConfigUpdated($config, newConfig, _msgSender());

        $config = newConfig;
    }

    function setRounds(RoundConfig[] calldata newRounds) external override onlyOwner {
        emit RoundsUpdated($rounds, newRounds, _msgSender());

        for (uint256 i; i < newRounds.length; ++i) {
            $rounds.push(newRounds[i]);
        }
    }

    function purchase() public payable override whenNotPaused {
        uint256 amountUSD = ethToUsd(msg.value);
        _sync($currentRoundIndex, address(0), amountUSD, _msgSender());
    }

    function purchase(address account) public payable override whenNotPaused {
        uint256 amountUSD = ethToUsd(msg.value);
        _sync($currentRoundIndex, address(0), amountUSD, account);
    }

    function purchaseUSDC(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        IERC20(USDC).transferFrom(sender, address(this), amount);

        uint256 amountScaled = amount * USDC_TO_WEI_PRECISION;
        _sync($currentRoundIndex, USDC, amountScaled, sender);
    }

    function purchaseDAI(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        IERC20(DAI).transferFrom(sender, address(this), amount);
        _sync($currentRoundIndex, DAI, amount, sender);
    }

    receive() external payable {
        purchase();
    }

    function _sync(uint256 roundIndex, address asset, uint256 amountUSD, address account) private {
        PresaleConfig memory _config = $config;
        RoundConfig[] memory _rounds = $rounds;

        uint256 _userTokensAllocated = $userTokensAllocated[account];
        uint256 userAllocationRemaining = _config.maxUserAllocation - _userTokensAllocated;

        uint256 remainingUSD = amountUSD;
        uint256 roundAllocationRemaining;

        for (uint256 i = roundIndex; i < _rounds.length; ++i) {
            RoundConfig memory _round = _rounds[i];
            roundAllocationRemaining = _round.tokensAllocated - ($raisedUSD[i] * _round.tokenPrice);

            if (roundAllocationRemaining == 0) continue;

            uint256 _tokensAllocated = remainingUSD / _round.tokenPrice;

            if (_tokensAllocated > roundAllocationRemaining) {
                _tokensAllocated = roundAllocationRemaining;
            }
            if (_tokensAllocated > userAllocationRemaining) {
                _tokensAllocated = userAllocationRemaining;
            }

            if (_tokensAllocated > 0) {
                uint256 tokensCostUSD = _tokensAllocated * _round.tokenPrice;
                remainingUSD -= tokensCostUSD;

                roundAllocationRemaining -= _tokensAllocated;
                userAllocationRemaining -= _tokensAllocated;

                if (asset == address(0)) {
                    _deposit(i, asset, tokensCostUSD / ethPrice(), tokensCostUSD, account);
                } else {
                    _deposit(i, asset, tokensCostUSD, tokensCostUSD, account);
                }
            }
        }

        $userTokensAllocated[account] = _config.maxUserAllocation - userAllocationRemaining;

        if (remainingUSD > 0) {
            _refund(asset, remainingUSD, account);
        }
    }

    function _deposit(uint256 roundIndex, address asset, uint256 amount, uint256 amountUSD, address account) private {
        PresaleConfig memory _config = $config;
        RoundConfig memory _round = $rounds[roundIndex];

        require(block.timestamp >= _config.startDate, "RAISE_NOT_STARTED");
        require(block.timestamp <= _config.endDate, "RAISE_ENDED");
        require(amountUSD >= _config.minDepositAmount || _config.minDepositAmount == 0, "MIN_DEPOSIT_AMOUNT");

        $raisedUSD[roundIndex] += amountUSD;
        $totalRaisedUSD += amountUSD;

        if ($raisedUSD[roundIndex] * _round.tokenPrice == _round.tokensAllocated) {
            $currentRoundIndex++;
        }

        emit Deposit(roundIndex, asset, amount, amountUSD, account);
    }

    function _refund(address asset, uint256 amountUSD, address account) private {
        if (asset == USDC) {
            IERC20(USDC).transfer(account, amountUSD / USDC_TO_WEI_PRECISION);
        } else if (asset == DAI) {
            IERC20(DAI).transfer(account, amountUSD);
        } else {
            uint256 amountInWei = amountUSD * PRECISION / ethPrice();
            payable(account).transfer(amountInWei);
        }

        emit Refund(asset, amountUSD, account);
    }
}
