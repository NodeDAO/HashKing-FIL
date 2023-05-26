// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @title Interface for Beneficiary
 */
interface IBeneficiary {
    function operator() external view returns (uint256);

    function nodeId() external view returns (uint256);
}
