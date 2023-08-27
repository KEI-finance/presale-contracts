// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

contract DummyContract {

    event Fallback(bytes data, uint256 indexed value, address indexed sender);

    receive() external payable {
        _fallback();
    }

    fallback() external payable {
        _fallback();
    }

    function _fallback() internal {
        emit Fallback(msg.data, msg.value, msg.sender);
    }
}
