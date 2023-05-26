
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

//import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Interface for INFIL
 */
interface INFIL is IERC20Upgradeable {
    /**
     * @notice mint nFIL
     * @param _amount mint amount
     * @param _account mint account
     */
    function whiteListMint(uint256 _amount, address _account) external;

    /**
     * @notice burn nFIL
     * @param _amount burn amount
     * @param _account burn account
     */
    function whiteListBurn(uint256 _amount, address _account) external;

    event LiquidStakingContractSet(address _OldLiquidStakingContractAddress, address _liquidStakingContractAddress);
}
