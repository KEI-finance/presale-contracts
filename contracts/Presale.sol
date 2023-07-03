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

    mapping(Round => mapping(address => uint256)) private userDepositsUSD;
    mapping(Round => mapping(address => uint256)) private userTokenBalances;

    constructor(uint48 startsAt_, uint48 endsAt_, address payable withdrawTo_) {
        _updateDates(startsAt_, endsAt_);
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

    function updateDates(uint48 newStartsAt, uint48 newEndsAt) external override onlyOwner {
        _updateDates(newStartsAt, newEndsAt);
    }

    function setWithdrawTo(address payable account) external onlyOwner {
        _setWithdrawTo(account);
    }

    function setRounds(Round[] memory rounds) external onlyOwner {
        for (uint256 i; i < rounds.length; ++i) {
            Round memory _round = rounds[i];

            $rounds.push(_round);

            emit RoundSet(i, _round, _msgSender());
        }
    }

    function depositETH() public payable override whenNotPaused {
        uint256 _currentRoundIndex = $currentRoundIndex;
        uint256 usdAmount = ethToUsd(msg.value);

        $withdrawTo.transfer(msg.value);
        _sync(_currentRoundIndex, address(0), msg.value, _msgSender(), usdAmount);
    }

    function depositUSDC(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;
        IERC20(USDC).transferFrom(sender, $withdrawTo, amount);

        uint256 amountScaled = amount * USDC_TO_WEI_PRECISION;
        _sync(_currentRoundIndex, USDC, sender, amount, amountScaled);
    }

    function depositDAI(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        uint256 _currentRoundIndex = $currentRoundIndex;

        IERC20(DAI).transferFrom(sender, $withdrawTo, amount);
        _sync(_currentRoundIndex, DAI, sender, amount, amount);
    }

    receive() external payable whenNotPaused {
        depositETH();
    }

    function _updateDates(uint48 _newStartsAt, uint48 _newEndsAt) private {
        uint48 _startsAt = $startsAt;
        uint48 _endsAt = $endsAt;

        require(block.timestamp <= _startsAt, "PRESALE_STARTED");
        require(_newStartsAt <= _newEndsAt, "INVALID_DATES");

        emit DatesUpdated(_startsAt, _newStartsAt, _endsAt, _newEndsAt, _msgSender());

        $startsAt = _newStartsAt;
        $endsAt = _newEndsAt;
    }

    function _setWithdrawTo(address payable newWithdrawTo) private {
        require(newWithdrawTo != address(0), "INVALID_WITHDRAW_TO");

        emit WithdrawToUpdated($withdrawTo, newWithdrawTo, _msgSender());

        $withdrawTo = newWithdrawTo;
    }

    function _sync(uint256 roundIndex, address asset, address account, uint256 usdAmount) private {
        Round storage $round = $rounds[startingRoundIndex];
        uint256 _remaining = $round.cap - $round.totalRaisedUSD;
        uint256 _roundsLength = $rounds.length;

        uint256 _depositAmount = usdAmount;
        uint256 _currentRoundIndex = roundIndex;

        while (_remaining > 0 && _currentRoundIndex < _roundsLength) {
            if (_depositAmount >= _remaining) {
                _deposit(_currentRoundIndex, account, _remaining);

                uint256 _leftOver = _depositAmount - _remaining;

                $currentRoundIndex += 1;
                _currentRoundIndex = $currentRoundIndex;

                $round = $rounds[_currentRoundIndex];
                _remaining = $round.cap - $round.totalRaisedUSD;

                if (_currentRoundIndex == _roundsLength - 1 && _leftOver > 0) {
                    _refund(asset, account, _leftOver);
                }
            } else {
                _deposit(_currentRoundIndex, account, _depositAmount);
                break;
            }
        }
    }

    function _deposit(uint256 roundIndex, address account, uint256 amount, uint256 amountUSD) private {
        Round storage $round = $rounds[roundIndex];

        require(block.timestamp >= $startsAt, "RAISE_NOT_STARTED");
        require(block.timestamp <= $endsAt, "RAISE_ENDED");
        require(amountUSD >= $round.minDeposit && $round.minDeposit != 0, "MIN_DEPOSIT_AMOUNT");
        require(amountUSD + $round.userDepositsUSD[account] <= $round.userCap, "EXCEED_USER_CAP");

        uint256 tokenAmount = usdToToken($round.price, amountUSD);

        $round.totalRaisedUSD += amountUSD;
        $round.userDepositsUSD[account] += amountUSD;
        $round.userTokenBalances[account] += tokenAmount;

        $totalRaisedUSD += amountUSD;

        emit Deposit(roundIndex, asset, account, amount, amountUSD, _msgSender());
    }

    function _refund(address asset, address account, uint256 usdAmount) private {
        if (asset == address(0)) {
            uint256 amountInWei = usdAmount * PRECISION / ethPrice();
            payable(account).transfer(amountInWei);
        } else {
            IERC20(asset).transfer(account, usdAmount);
        }
    }
}
