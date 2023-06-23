// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "./IPreSale.sol";

contract PreSale is IPreSale, Ownable2Step, ReentrancyGuard {

    mapping(address => uint256) balances;

    function raisedAmount() public view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        uint256 amount = msg.value;

        balances[msg.sender] += amount;

        emit Deposit(amount, msg.sender);
    }

    function withdraw(address payable _to) external onlyOwner {
        uint256 amount = raisedAmount();

        (bool success, bytes memory data) = _to.call{value: amount}("");
        require(success, "FAILED_WITHDRAW");

        emit Withdrawal(amount, _to, msg.sender);
    }

    function refund(address payable _to) external nonReentrant {
        require(balances[msg.sender] > 0, "ZERO_BALANCE");

        uint256 amount = balances[msg.sender];

        balances[msg.sender] = 0;

        (bool success, bytes memory data) = _to.call{value: amount}("");
        require(success, "FAILED_REFUND");

        emit Refund(amount, msg.sender);
    }
}
