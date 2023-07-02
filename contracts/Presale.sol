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

    AggregatorV3Interface public immutable ORACLE = AggregatorV3Interface(0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612);

    uint256 private immutable PRECISION = 1e18;
    uint256 private immutable ETH_TO_WEI_PRECISION = 1e10;
    uint256 private immutable USDC_TO_WEI_PRECISION = 1e12;

    uint48 private $startsAt;
    uint48 private $endsAt;

    Round[] private $rounds;
    uint256 private $currentRoundIndex;

    uint256 private $totalRaisedUSD;

    address payable public $withdrawTo;

    constructor(uint48 startsAt_, uint48 endsAt_, address payable withdrawTo_) {
        $startsAt = startsAt_;
        $endsAt = endsAt_;

        _setWithdrawTo(withdrawTo_);
    }

    function startsAt() external view override returns (uint48) {
        return $startsAt;
    }

    function endsAt() external view override returns (uint48) {
        return $endsAt;
    }

    function currentRoundIndex() external view override returns (uint256) {
        return $currentRoundIndex;
    }

    function totalRounds() external view override returns (uint256) {
        return $rounds.length;
    }

    function totalRaisedUSD() external view override returns (uint256) {
        return $totalRaisedUSD;
    }

    function totalRaisedInRoundUSD(uint256 roundIndex) external view override returns (uint256) {
        return $rounds[roundIndex].totalRaisedUSD;
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

    function usdToToken(uint256 tokenPrice, uint256 amount) public pure returns (uint256) {
        return (amount * PRECISION) / tokenPrice;
    }

    function updateDates(uint48 _newStartsAt, uint48 _newEndsAt) external override onlyOwner {
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

    function updateRoundConfig(
        uint256 _roundIndex,
        uint256 _newCap,
        uint256 _newUserCap,
        uint256 _newMinDeposit,
        uint256 _newMaxDeposit,
        uint256 _newPrice
    ) external onlyOwner {
        address sender = _msgSender();

        Round storage $round = $rounds[_roundIndex];

        $round.cap = _newCap;
        $round.userCap = _newUserCap;
        $round.minDeposit = _newMinDeposit;
        $round.maxDeposit = _newMaxDeposit;
        $round.price = _newPrice;

        emit RoundUpdated(_roundIndex, _newCap, _newUserCap, _newMinDeposit, _newMaxDeposit, _newPrice, sender);
    }

    function depositETH() public payable override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;
        uint256 usdAmount = ethToUsd(msg.value);

        $withdrawTo.transfer(msg.value);
        _sync(_currentRoundIndex, sender, usdAmount);

        emit DepositETH(_currentRoundIndex, msg.value, usdAmount, sender);
    }

    function depositUSDC(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;
        IERC20(USDC).transferFrom(sender, $withdrawTo, amount);

        uint256 amountScaled = amount * USDC_TO_WEI_PRECISION;
        _sync(_currentRoundIndex, sender, amountScaled);

        emit Deposit(_currentRoundIndex, USDC, amountScaled, sender);
    }

    function depositDAI(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;

        IERC20(DAI).transferFrom(sender, $withdrawTo, amount);
        _sync(_currentRoundIndex, sender, amount);

        emit Deposit(_currentRoundIndex, DAI, amount, sender);
    }

    receive() external payable whenNotPaused {
        depositETH();
    }

    function _setWithdrawTo(address payable newWithdrawTo) private {
        require(newWithdrawTo != address(0), "INVALID_WITHDRAW_TO");

        address sender = _msgSender();

        emit WithdrawToUpdated($withdrawTo, newWithdrawTo, sender);
        $withdrawTo = newWithdrawTo;
    }

    function _sync(uint256 roundIndex, address account, uint256 usdAmount) private {
        Round storage $round = $rounds[roundIndex];

        uint256 _remaining = $round.cap - $round.totalRaisedUSD;

        uint256 depositAmount = usdAmount;

        while (_remaining > 0 && $round.cap != 0) {
            if (depositAmount >= _remaining) {
                _deposit(roundIndex, account, _remaining);

                $currentRoundIndex += 1;
                $round = $rounds[$currentRoundIndex];
                _remaining = $round.cap - $round.totalRaisedUSD;

                uint256 carryOver = depositAmount - _remaining;
                depositAmount = carryOver;
            } else {
                _deposit(roundIndex, account, depositAmount);
            }
        }
    }

    function _deposit(uint256 roundId, address account, uint256 usdAmount) private {
        Round storage $round = $rounds[roundId];

        require(block.timestamp >= $startsAt, "RAISE_NOT_STARTED");
        require(block.timestamp <= $endsAt, "RAISE_ENDED");
        require(usdAmount >= $round.minDeposit && $round.minDeposit != 0, "MIN_DEPOSIT_AMOUNT");
        require(usdAmount <= $round.maxDeposit && $round.maxDeposit != 0, "MAX_DEPOSIT_AMOUNT");
        require(usdAmount + $round.userDepositsUSD[account] <= $round.userCap, "EXCEED_USER_CAP");

        uint256 tokenAmount = usdToToken($round.price, usdAmount);

        $round.totalRaisedUSD += usdAmount;
        $round.userDepositsUSD[account] += usdAmount;
        $round.userTokenBalances[account] += tokenAmount;

        $totalRaisedUSD += usdAmount;
    }
}
