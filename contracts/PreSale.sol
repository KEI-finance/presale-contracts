// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

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

    mapping(uint256 => Round) private rounds;

    address public override withdrawTo;

    constructor(uint256 startsAt_, uint256 endsAt_, address withdrawTo_, address USDC_, address DAI_) {
        _startsAt = startsAt_;
        _endsAt = endsAt_;

        USDC = USDC_;
        DAI = DAI_;

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

    receive() external payable whenNotPaused {
        // checks

        uint256 amount = msg.value;

        _balances[msg.sender] += amount;

        emit Deposit(amount, msg.sender);
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
