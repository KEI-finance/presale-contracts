// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./IPreSale.sol";

contract PreSale is IPreSale, Ownable2Step, ReentrancyGuard {
    mapping(address => uint256) private _balances;

    function totalRaised() public view returns (uint256) {
        return address(this).balance;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return _balances[_account];
    }

    receive() external payable {
        uint256 amount = msg.value;

        _balances[msg.sender] += amount;

        emit Deposit(amount, msg.sender);
    }

    function withdraw(address payable _to) external onlyOwner {
        uint256 amount = totalRaised();

        (bool success,) = _to.call{value: amount}("");
        require(success, "FAILED_WITHDRAW");

        emit Withdrawal(amount, _to, msg.sender);
    }

    function refund(address payable _to) external nonReentrant {
        require(_balances[msg.sender] > 0, "ZERO_BALANCE");

        uint256 amount = _balances[msg.sender];

        _balances[msg.sender] = 0;

        (bool success,) = _to.call{value: amount}("");
        require(success, "FAILED_REFUND");

        emit Refund(amount, msg.sender);
    }
}
