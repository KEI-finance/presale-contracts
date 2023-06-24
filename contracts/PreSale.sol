// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./IPreSale.sol";

contract PreSale is IPreSale, Ownable2Step, ReentrancyGuard {
    uint256 private _raiseDeadline;

    mapping(address => uint256) private _balances;

    constructor(uint256 _initialDeadline) {
        _raiseDeadline = _initialDeadline;
    }

    function totalRaised() external view override returns (uint256) {
        return address(this).balance;
    }

    function balanceOf(address _account) external view override returns (uint256) {
        return _balances[_account];
    }

    function raiseDeadline() external view override returns (uint256) {
        return _raiseDeadline;
    }

    function setRaiseDeadline(uint256 _newDeadline) external override onlyOwner {
        uint256 _prevDeadline = _raiseDeadline;
        _raiseDeadline = _newDeadline;
        emit DeadlineUpdated(_prevDeadline, _newDeadline, msg.sender);
    }

    receive() external payable {
        require(block.timestamp <= _raiseDeadline, "RAISE_CLOSED");

        uint256 amount = msg.value;

        _balances[msg.sender] += amount;

        emit Deposit(amount, msg.sender);
    }

    function withdraw(address payable _to) external override onlyOwner {
        uint256 amount = address(this).balance;

        (bool success,) = _to.call{value: amount}("");
        require(success, "FAILED_WITHDRAW");

        emit Withdrawal(amount, _to, msg.sender);
    }

    function refund(address payable _to) external override nonReentrant {
        require(block.timestamp <= _raiseDeadline, "RAISE_CLOSED");
        require(_balances[msg.sender] > 0, "ZERO_BALANCE");

        uint256 amount = _balances[msg.sender];

        _balances[msg.sender] = 0;

        (bool success,) = _to.call{value: amount}("");
        require(success, "FAILED_REFUND");

        emit Refund(amount, msg.sender);
    }
}
