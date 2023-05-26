// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @title Interface for vault
 */
interface IVault {
    function setRecipient(address payable _recipient) external;

    function setReserves(uint256 _reserves) external;
}
