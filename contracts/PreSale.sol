// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IPreSale.sol";

contract PreSale is IPreSale, Ownable2Step, ReentrancyGuard, Pausable {
    address public immutable USDC;
    address public immutable DAI;

    uint256 private _startsAt;
    uint256 private _endsAt;

    mapping(address => uint256) private _balances;

    mapping(uint256 => Round) private _rounds;

    uint256 private _totalRaisedUSD;

    address public override withdrawTo;

    AggregatorV3Interface public oracle;

    constructor(uint256 startsAt_, uint256 endsAt_, address withdrawTo_, address USDC_, address DAI_, address oracle_) {
        _startsAt = startsAt_;
        _endsAt = endsAt_;

        USDC = USDC_;
        DAI = DAI_;

        oracle = AggregatorV3Interface(oracle_);

        _setWithdrawTo(withdrawTo_);
    }

    function updateDates(uint256 _newStartsAt, uint256 _newEndsAt) external onlyOwner {
        emit DatesUpdated(_startsAt, _endsAt, _newStartsAt, _newEndsAt, msg.sender);

        _startsAt = _newStartsAt;
        _endsAt = _newEndsAt;
    }

    function setWithdrawTo(address _newWithdrawTo) external onlyOwner {
        emit WithdrawToUpdated(_withdrawTo, _newWithdrawTo, msg.sender);

        _withdrawTo = _newWithdrawTo;
    }

    function updateRoundConfig(uint8 _roundId, uint256 _minDepositUSD, uint256 _maxDepositUsd) external onlyOwner {
        emit RoundConfigUpdated(_roundId, _minDepositUSD, _maxDepositUsd, msg.sender);

        _rounds[_roundId].minDepositUSD = _minDepositUSD;
        _rounds[_roundId].maxDepositUSD = _maxDepositUsd;
    }

    function depositETH() external payable override whenNotPaused {
        // checks

        uint8 _currentRound = currentRound();

        _rounds[_currentRound].deposits[msg.sender][address(0)] += amount;
        _rounds[_currentRound].totalDepositsPerAsset[address(0)] += amount;

        // convert eth to usd using oracle, increase _totalRaisedUSD by value
    }

    function depositUSDC(uint256 amount) external override whenNotPaused {
        // checks

        uint8 _currentRound = currentRound();

        _rounds[_currentRound].deposits[msg.sender][USDC] += amount;
        _rounds[_currentRound].totalDepositsPerAsset[USDC] += amount;

        _totalRaisedUSD += amount;

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
    }

    function depositDAI(uint256 amount) external override whenNotPaused {
        // checks

        uint8 _currentRound = currentRound();

        _rounds[_currentRound].deposits[msg.sender][DAI] += amount;
        _rounds[_currentRound].totalDepositsPerAsset[DAI] += amount;

        _totalRaisedUSD += amount;

        IERC20(DAI).transferFrom(msg.sender, address(this), amount);
    }

    receive() external payable whenNotPaused {
        // checks

        emit Deposit(msg.value, address(0), msg.sender);
    }

    function withdraw() external override whenNotPaused onlyOwner {
        uint256 amount = address(this).balance;

        (bool success,) = _withdrawTo.call{value: amount}("");
        require(success, "FAILED_WITHDRAW");

        emit Withdrawal(amount, _withdrawTo, msg.sender);
    }

    function _setWithdrawTo(address account) private {
        require(account != address(0), "INVALID_WITHDRAW_TO");

        emit WithdrawToUpdated(withdrawTo, account, msg.sender);
        withdrawTo = account;
    }
}
