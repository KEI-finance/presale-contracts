// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IPresale.sol";

contract Presale is IPresale, Ownable2Step, ReentrancyGuard, Pausable {

    address public immutable override USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    address public immutable override DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    AggregatorV3Interface public immutable ORACLE = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;

    uint256 private immutable PRECISION = 1e18;
    uint256 private immutable ETH_TO_WEI_PRECISION = 1e10;
    uint256 private immutable USDC_TO_WEI_PRECISION = 1e12;

    uint48 private $startsAt;
    uint48 private $endsAt;

    uint8 private $currentRoundIndex;
    uint256 private $totalRaisedUSD;
    Round[] private $rounds;

    address payable public $withdrawTo;

    constructor(uint256 startsAt_, uint256 endsAt, address payable withdrawTo_) {
        $startsAt = startsAt_;
        $endsAt = endsAt;
        _setWithdrawTo(withdrawTo_);
    }

    function startsAt() external view override returns (uint48) {
        return $startsAt;
    }

    function endsAt() external view override returns (uint48) {
        return $endsAt;
    }

    function currentRoundIndex() external view override returns (uint8) {
        return $currentRoundIndex;
    }

    function totalRounds() external view override returns (uint8) {
        return $rounds.length;
    }

    function totalRaisedUSD() external view override returns (uint256) {
        return $totalRaisedUSD;
    }

    function totalRaisedInRoundUSD(uint256 roundIndex) external view override returns (uint256) {
        return $rounds[roundIndex].totalRaisedUSD;
    }

    function ethPrice() public view returns (uint256) {
        (, int256 price,,,) = oracle.latestRoundData();
        return uint256(price * 1e10);
    }

    function getConversionRate(uint256 amount) public view returns (uint256) {
        uint256 _ethPrice = ethPrice();
        uint256 _ethAmountInUsd = (_ethPrice * amount) / 1e18;
        return _ethAmountInUsd;
    }

    function updateDates(uint256 _newStartsAt, uint256 _newEndsAt) external onlyOwner {
        address sender = _msgSender();

        require(block.timestamp <= $startsAt, "PRESALE_STARTED");
        require(_newStartsAt <= _newEndsAt, "INVALID_DATES");

        emit DatesUpdated($startsAt, _newStartsAt, $endsAt, _newEndsAt, sender);

        $startsAt = _newStartsAt;
        $endsAt = _newEndsAt;
    }

    function setWithdrawTo(address payable account) external onlyOwner {
        _setWithdrawTo(account);
    }

    function updateRoundConfig(uint8 _roundIndex, uint256 _newCap, uint256 _newUserCap, uint256 _newMinDeposit, uint256 _newMaxDeposit)
    external
    onlyOwner
    {
        address sender = _msgSender();

        Round storage $round = $rounds[_roundIndex];

        $round.cap = _newCap;
        $round.userCap = _newUserCap;
        $round.minDeposit = _newMinDeposit;
        $round.maxDeposit = _newMaxDeposit;

        emit RoundUpdated(_roundIndex, _newCap, _newUserCap, _newMinDeposit, _newMaxDeposit, sender);
    }

    function depositETH() public payable override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;
        Round storage $round = _rounds[_currentRoundIndex];

        uint256 usdAmount = getConversionRate(msg.value);
        _sync(_currentRoundIndex, address(0), sender, usdAmount, sender);

        emit DepositETH(_currentRoundIndex, msg.value, usdAmount, sender);
    }

    function depositUSDC(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;
        Round storage $round = $rounds[_currentRoundIndex];

        IERC20(USDC).transferFrom(sender, address(this), amount);

        uint256 amountScaled = amount * USDC_TO_WEI_PRECISION;

        _sync(_currentRoundIndex, USDC, sender, amountScaled, sender);

        emit Deposit(_currentRoundIndex, USDC, amountScaled, sender);
    }

    function depositDAI(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;
        Round storage $round = $rounds[_currentRoundIndex];

        IERC20(DAI).transferFrom(sender, address(this), amount);

        _sync(_currentRoundIndex, DAI, sender, amount, sender);

        emit Deposit(_currentRoundIndex, DAI, amount, sender);
    }

    receive() external payable whenNotPaused {
        depositETH();
    }

    function _setWithdrawTo(address payable account) private {
        require(account != address(0), "INVALID_WITHDRAW_TO");

        address sender = _msgSender();

        emit WithdrawToUpdated(withdrawTo, account, sender);
        withdrawTo = account;
    }

    function _sync(uint8 roundIndex, address asset, address account, uint256 amount, address sender) private {
        Round memory round = $rounds[roundIndex];

        uint256 _cap = round.cap;
        uint256 _raised = round.totalRaised;

        if (_raised + amount >= _cap) {
            uint256 _currentRoundIndexRemaining = _cap - _raised;

            _deposit(roundIndex, asset, account, _currentRoundIndexRemaining, sender);

            uint8 _newRound = roundIndex + 1;

            if (_newRound <= _maxRounds - 1) {
                $currentRoundIndex = _newRound;
                _sync($currentRoundIndex, asset, account, _raised + amount - _cap, sender);
            }
        } else {
            _deposit(roundIndex, asset, account, amount, sender);
        }
    }

    function _deposit(uint8 roundId, address asset, address account, uint256 usdAmount, address sender) private {
        Round storage $round = $rounds[roundId];

        require(block.timestamp >= $startsAt, "RAISE_NOT_STARTED");
        require(block.timestamp <= $endsAt, "RAISE_ENDED");
        require(usdAmount >= $round.minDeposit, "MIN_DEPOSIT_AMOUNT");
        require(usdAmount <= $round.maxDeposit, "MAX_DEPOSIT_AMOUNT");
        require(usdAmount + $round.userDeposits[sender] <= $round.userCap, "EXCEED_USER_CAP");

        $round.totalRaised += amount;
        $round.userDeposits[sender] += amount;

        _totalRaised += amount;
    }
}
