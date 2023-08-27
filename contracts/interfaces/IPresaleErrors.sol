// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.19;

import "../interfaces/IPresale.sol";

interface IPresaleErrors {
    enum PresaleState {
        PENDING,
        OPEN,
        CLOSED
    }

    error PresaleInvalidState(PresaleState state);
    error PresaleInvalidContract(address target);
    error PresaleInvalidAddress(address target);
    error PresaleInvalidStartDate(uint256 startDate, uint256 currentDate);
    error PresaleInvalidPurchase(IPresale.PurchaseConfig config, IPresale.Receipt receipt);
    error PresaleInsufficientRounds();
    error PresaleInsufficientAmount(uint256 received, uint256 min);
    error PresaleInsufficientAllocation(uint256 received, uint256 min);
    error PresaleInsufficientMaxUserAllocation(uint256 received, uint256 min);
}
