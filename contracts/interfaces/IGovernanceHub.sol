// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/IVault.sol";
import "contracts/interfaces/INFIL.sol";
import "contracts/interfaces/ILiquidStaking.sol";
import "contracts/interfaces/IOwnable.sol";

/**
 * @title Interface for GovernanceHub
 */
interface IGovernanceHub is INFIL, IVault, ILiquidStaking, IOwnable {
    function setGovernance(address gov) external;

    function claimRewards(bool needReward, uint256 _amount, bytes calldata params) external;

    function depositFil(uint256 to, uint256 amount) external;

    function withdrawFil(uint256 amount, bytes calldata params) external;

    function setOperatorAndNode(uint256 _operator, uint256 _nodeId) external;

    function setVaultPer(uint256 _liquidStakingPer, uint256 _operatoVaultPer) external;

    function setKingHashVault(address _vault) external;

    function setOperatoVault(address _vault) external;

    function setLiquidStaking(address _liquidStaking) external;

    function changeBeneficiary(bytes memory params) external;

    function claimBalanceRewards(bool needReward) external;

    function withdrawBalanceFil() external;

    function setLiquidStakingRewardAddress(address _liquidStakingRewardAddress) external;
}
