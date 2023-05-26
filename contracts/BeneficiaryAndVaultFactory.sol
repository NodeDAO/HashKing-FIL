// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "contracts/interfaces/IBeneficiaryAndVaultFactory.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "contracts/Vault.sol";
import "contracts/Beneficiary.sol";
import "contracts/interfaces/IOwnable.sol";

contract BeneficiaryAndVaultFactory is IBeneficiaryAndVaultFactory, OwnableUpgradeable, UUPSUpgradeable {
    address public vaultBeacon;
    address public beneficiaryBeacon;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize(address _vaultImplementationAddress, address _beneficiaryImplementationAddress)
        public
        initializer
    {
        __Ownable_init();
        __UUPSUpgradeable_init();

        UpgradeableBeacon _vaultBeacon = new UpgradeableBeacon(_vaultImplementationAddress);
        UpgradeableBeacon _beneficiaryBeacon = new UpgradeableBeacon(_beneficiaryImplementationAddress);

        vaultBeacon = address(_vaultBeacon);
        beneficiaryBeacon = address(_beneficiaryBeacon);

        _vaultBeacon.transferOwnership(msg.sender);
        _beneficiaryBeacon.transferOwnership(msg.sender);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function createVault(address _recipient, uint256 _reserves) external returns (address) {
        address proxyAddress = address(
            new BeaconProxy(vaultBeacon, abi.encodeWithSelector(Vault.initialize.selector, _recipient, _reserves))
        );
        emit VaultProxyDeployed(proxyAddress);
        IOwnable(proxyAddress).transferOwnership(msg.sender);
        return proxyAddress;
    }

    function createBeneficiary(
        address _kingHashVault,
        address _operatorVault,
        uint256 _operatorVaultPer,
        address _liquidStaking,
        uint256 _liquidStakingPer,
        uint256 _nodeId,
        uint256 _operator
    ) external returns (address) {
        address proxyAddress = address(
            new BeaconProxy(beneficiaryBeacon, abi.encodeWithSelector(
                Beneficiary.initialize.selector,
                _kingHashVault,
                _operatorVault,
                _operatorVaultPer,
                _liquidStaking,
                _liquidStakingPer,
                _nodeId,
                _operator
            ))
        );
        emit BeneficiaryProxyDeployed(proxyAddress);
        IOwnable(proxyAddress).transferOwnership(msg.sender);
        return proxyAddress;
    }
}
