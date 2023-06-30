// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IPreSale.sol";

contract PreSale is IPreSale, Ownable2Step, ReentrancyGuard, Pausable {
    uint256 private _startsAt;

    uint256 private _deadline;

    uint8 private _currentRound;

    uint8 private _maxRounds;

    uint256 private _totalRaised;

    mapping(uint8 => Round) private _rounds;

    address public immutable USDC;

    address public immutable DAI;

    address payable public withdrawTo;

    AggregatorV3Interface public oracle;

    constructor(
        uint256 startsAt_,
        uint256 deadline_,
        address USDC_,
        address DAI_,
        address oracle_,
        uint8 maxRounds_,
        address payable withdrawTo_
    ) {
        _startsAt = startsAt_;
        _deadline = deadline_;

        USDC = USDC_;
        DAI = DAI_;

        oracle = AggregatorV3Interface(oracle_);

        _maxRounds = maxRounds_;

        _rounds[0].startsAt = startsAt_;

        _setWithdrawTo(withdrawTo_);
    }

    function startsAt() external view override returns (uint256) {
        return _startsAt;
    }

    function deadline() external view override returns (uint256) {
        return _deadline;
    }

    function currentRound() external view override returns (uint8) {
        return _currentRound;
    }

    function maxRounds() external view override returns (uint8) {
        return _maxRounds;
    }

    function totalRaised() external view override returns (uint256) {
        return _totalRaised;
    }

    function totalRaisedInRound(uint8 roundId) external view override returns (uint256) {
        return _rounds[roundId].totalRaised;
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

    function updateDates(uint256 _newStartsAt, uint256 _newDeadline) external onlyOwner {
        require(block.timestamp <= _startsAt, "PRESALE_STARTED");
        require(_newStartsAt <= _newDeadline, "INVALID_DATES");

        emit DatesUpdated(_startsAt, _deadline, _newStartsAt, _newDeadline, msg.sender);

        _startsAt = _newStartsAt;
        _deadline = _newDeadline;
    }

    function setWithdrawTo(address payable account) external onlyOwner {
        _setWithdrawTo(account);
    }

    function updateRoundConfig(uint8 _roundId, uint256 _minDeposit, uint256 _maxDeposit, uint256 _cap, uint256 _userCap)
        external
        onlyOwner
    {
        RoundConfig memory _config =
            RoundConfig({minDeposit: _minDeposit, maxDeposit: _maxDeposit, cap: _cap, userCap: _userCap});

        _rounds[_roundId].config = _config;

        emit RoundConfigUpdated(_rounds[_currentRound].config, _config, msg.sender);
    }

    function depositETH() public payable override whenNotPaused {
        Round storage _round = _rounds[_currentRound];

        uint256 usdAmount = getConversionRate(msg.value);

        require(block.timestamp >= _startsAt, "RAISE_NOT_STARTED");
        require(block.timestamp <= _deadline, "RAISE_ENDED");
        require(usdAmount >= _round.config.minDeposit, "MIN_DEPOSIT_AMOUNT");
        require(usdAmount <= _round.config.maxDeposit, "MAX_DEPOSIT_AMOUNT");
        require(usdAmount + _round.userDeposits[msg.sender] <= _round.config.userCap, "EXCEED_USER_CAP");

        _sync(_currentRound, address(0), msg.sender, usdAmount);

        emit Deposit(_currentRound, address(0), usdAmount, msg.sender);
    }

    function depositUSDC(uint256 amount) external override whenNotPaused {
        Round storage _round = _rounds[_currentRound];

        uint256 amountScaled = amount * 1e12; // usdc is 6 decimals on arbitrum

        require(block.timestamp >= _startsAt, "RAISE_NOT_STARTED");
        require(block.timestamp <= _deadline, "RAISE_ENDED");
        require(amountScaled >= _round.config.minDeposit, "MIN_DEPOSIT_AMOUNT");
        require(amountScaled <= _round.config.maxDeposit, "MAX_DEPOSIT_AMOUNT");
        require(amountScaled + _round.userDeposits[msg.sender] <= _round.config.userCap, "EXCEED_USER_CAP");

        _sync(_currentRound, USDC, msg.sender, amountScaled);

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);

        emit Deposit(_currentRound, USDC, amount, msg.sender);
    }

    function depositDAI(uint256 amount) external override whenNotPaused {
        Round storage _round = _rounds[_currentRound];

        require(block.timestamp >= _startsAt, "RAISE_NOT_STARTED");
        require(block.timestamp <= _deadline, "RAISE_ENDED");
        require(amount >= _round.config.minDeposit, "MIN_DEPOSIT_AMOUNT");
        require(amount <= _round.config.maxDeposit, "MAX_DEPOSIT_AMOUNT");
        require(amount + _round.userDeposits[msg.sender] <= _round.config.userCap, "EXCEED_USER_CAP");

        _sync(_currentRound, DAI, msg.sender, amount);

        IERC20(DAI).transferFrom(msg.sender, address(this), amount);

        emit Deposit(_currentRound, DAI, amount, msg.sender);
    }

    receive() external payable whenNotPaused {
        depositETH();
    }

    function withdraw() external override whenNotPaused onlyOwner {
        uint256 ethBalance = address(this).balance;
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
        uint256 daiBalance = IERC20(DAI).balanceOf(address(this));

        withdrawTo.transfer(ethBalance);
        IERC20(USDC).transfer(withdrawTo, usdcBalance);
        IERC20(DAI).transfer(withdrawTo, daiBalance);

        emit Withdrawal(_totalRaised, withdrawTo, msg.sender);
    }

    function _setWithdrawTo(address payable account) private {
        require(account != address(0), "INVALID_WITHDRAW_TO");

        emit WithdrawToUpdated(withdrawTo, account, msg.sender);
        withdrawTo = account;
    }

    function _sync(uint8 roundId, address asset, address account, uint256 amount) private {
        uint256 _cap = _rounds[roundId].config.cap;
        uint256 _raised = _rounds[roundId].totalRaised;

        if (_raised + amount >= _cap) {
            uint256 _currentRoundRemaining = _cap - _raised;

            _deposit(roundId, asset, account, _currentRoundRemaining);

            _rounds[_currentRound].endsAt = block.timestamp;

            uint8 _newRound = _currentRound + 1;

            if (_newRound <= _maxRounds - 1) {
                _currentRound = _newRound;

                _rounds[_currentRound].startsAt = block.timestamp;

                _sync(_currentRound, asset, account, _raised + amount - _cap);
            }
        } else {
            _deposit(roundId, asset, account, amount);
        }
    }

    function _deposit(uint8 roundId, address asset, address account, uint256 amount) private {
        Round storage _round = _rounds[roundId];

        _round.totalRaised += amount;
        _round.deposits[account][asset] += amount;
        _round.depositsPerAsset[asset] += amount;
        _round.userDeposits[msg.sender] += amount;

        _totalRaised += amount;
    }
}
