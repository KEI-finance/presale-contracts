// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IPreSale.sol";

contract PreSale is IPreSale, Ownable2Step, ReentrancyGuard, Pausable {
    address public immutable USDC;
    address public immutable DAI;

    uint256 private _startsAt;
    uint256 private _deadline;

    uint8 private _currentRound;

    mapping(uint8 => Round) private _rounds;

    uint256 private _totalRaisedUSD;

    address payable public withdrawTo;

    AggregatorV3Interface public oracle;

    constructor(
        uint256 startsAt_,
        uint256 deadline_,
        address USDC_,
        address DAI_,
        address oracle_,
        address payable withdrawTo_
    ) {
        _startsAt = startsAt_;
        _deadline = deadline_;

        USDC = USDC_;
        DAI = DAI_;

        oracle = AggregatorV3Interface(oracle_);

        _rounds[0].startsAt = startsAt_;

        _setWithdrawTo(withdrawTo_);
    }

    function deadline() external view override returns (uint256) {
        return _deadline;
    }

    function currentRound() external view override returns (uint8) {
        return _currentRound;
    }

    function totalRaised() external view override returns (uint256) {
        return _totalRaisedUSD;
    }

    function ethPrice() external view override returns (uint256) {
        (, int price,,,) = oracle.latestRoundData();
        return uint256(price * 1e10);
    }

    function updateDates(uint256 _newStartsAt, uint256 _newEndsAt) external onlyOwner {
        emit DatesUpdated(_startsAt, _endsAt, _newStartsAt, _newEndsAt, msg.sender);

        _startsAt = _newStartsAt;
        _endsAt = _newEndsAt;
    }

    function setWithdrawTo(address payable account) external onlyOwner {
        _setWithdrawTo(account);
    }

    function updateRoundConfig(uint8 _roundId, uint256 _minDeposit, uint256 _maxDeposit, uint256 _cap)
        external
        onlyOwner
    {
        emit RoundConfigUpdated(_roundId, _minDeposit, _maxDeposit, msg.sender);

        _rounds[_roundId].minDeposit = _minDeposit;
        _rounds[_roundId].maxDeposit = _maxDeposit;
        _rounds[_roundId].cap = _cap;
    }

    function depositETH() external payable override whenNotPaused {
        // checks

        //        _sync(address(0), msg.sender, ...)

        // convert eth to usd using oracle, increase _totalRaisedUSD by value

        //        emit Deposit(_currentRound, address(0), msg.value, msg.sender);
    }

    function depositUSDC(uint256 amount) external override whenNotPaused {
        // checks

        _sync(_currentRound, USDC, msg.sender, amount);

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);

        emit Deposit(_currentRound, USDC, amount, msg.sender);
    }

    function depositDAI(uint256 amount) external override whenNotPaused {
        // checks

        _sync(_currentRound, DAI, msg.sender, amount);

        IERC20(DAI).transferFrom(msg.sender, address(this), amount);

        emit Deposit(_currentRound, DAI, amount, msg.sender);
    }

    receive() external payable whenNotPaused {
        // checks

        // convert eth to usd using oracle, increase _totalRaisedUSD by value

        //        emit Deposit(_currentRound, address(0), msg.value, msg.sender);
    }

    function withdraw() external override whenNotPaused onlyOwner {
        uint256 ethBalance = address(this).balance;
        uint256 usdcBalance = IERC20(USDC).balanceOf(address(this));
        uint256 daiBalance = IERC20(DAI).balanceOf(address(this));

        withdrawTo.transfer(ethBalance);
        IERC20(USDC).transfer(withdrawTo, usdcBalance);
        IERC20(DAI).transfer(withdrawTo, daiBalance);

        emit Withdrawal(_totalRaisedUSD, withdrawTo, msg.sender);
    }

    function _setWithdrawTo(address payable account) private {
        require(account != address(0), "INVALID_WITHDRAW_TO");

        emit WithdrawToUpdated(withdrawTo, account, msg.sender);
        withdrawTo = account;
    }

    function _sync(uint8 roundId, address asset, address account, uint256 amount) private {
        uint256 _cap = _rounds[roundId].cap;
        uint256 _deposits = _rounds[roundId].totalDeposits;

        if (_deposits + amount >= _cap) {
            uint256 _currentRoundRemaining = _cap - _deposits;

            _deposit(roundId, asset, account, _currentRoundRemaining);

            uint8 _newRound = _currentRound + 1;

            _currentRound = _newRound;

            _sync(_currentRound, asset, account, _deposits + amount - _cap);
        } else {
            _deposit(roundId, asset, account, amount);
        }
    }

    function _deposit(uint8 roundId, address asset, address account, uint256 amount) private {
        _rounds[roundId].totalDeposits += amount;
        _rounds[roundId].deposits[account][asset] += amount;
        _rounds[roundId].depositsPerAsset[asset] += amount;

        _totalRaisedUSD += amount;
    }
}
