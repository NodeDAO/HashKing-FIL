// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IBeneficiaryAndVaultFactory {
    function createVault(address _recipient, uint256 _reserves) external returns (address);

    function createBeneficiary(
        address _kingHashVault,
        address _operatorVault,
        uint256 _operatorVaultPer,
        address _liquidStaking,
        uint256 _liquidStakingPer,
        uint256 _nodeId,
        uint256 _operator
    ) external returns (address);

    event VaultProxyDeployed(address proxyAddress);
    event BeneficiaryProxyDeployed(address proxyAddress);
}
