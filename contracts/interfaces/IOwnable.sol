// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @title Interface for Ownable
 */
interface IOwnable {
    function transferOwnership(address newOwner) external;
}
