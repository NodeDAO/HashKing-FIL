// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @title Interface for LiquidStaking
 */
interface ILiquidStaking {
    function addBeneficiary(address addr) external returns (bool);

    function delBeneficiary(address addr) external returns (bool);

    function beneficiarys() external view returns (address[] memory);

    function setTotalPoolFilLimit(uint256 _amount) external;

    // 质押给节点
    function depositFil(uint256 amount) external;

    // 还本
    function repayment() external payable;

    function claimRewards(bool needReward) external payable;
}
