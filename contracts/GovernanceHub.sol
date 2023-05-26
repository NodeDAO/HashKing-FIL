// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "contracts/Beneficiary.sol";
import "contracts/Vault.sol";
import "contracts/interfaces/IGovernanceHub.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "contracts/interfaces/IBeneficiaryAndVaultFactory.sol";

struct Call {
    address target;
    bytes callData;
}

contract GovernanceHub is OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    event LiquidStakingChanged(address _from, address _to);
    event BeneficiaryAndVaultFactoryChanged(address _from, address _to);
    event KinghashVaultContractChanged(address _from, address _to);

    //admin list
    EnumerableSet.AddressSet private _admin;
    address public beneficiaryFactoryAddress;
    address public kinghashVaultContract;
    address public liquidStakingContract;

    modifier onlyAdmin() {
        require(_admin.contains(msg.sender) || owner() == msg.sender, "invalid _admin");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize(
        address _beneficiaryFactoryAddress,
        address _kinghashVaultContract,
        address _liquidStakingContract
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        beneficiaryFactoryAddress = _beneficiaryFactoryAddress;
        kinghashVaultContract = _kinghashVaultContract;
        liquidStakingContract = _liquidStakingContract;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function addAdmin(address addr) external onlyOwner returns (bool) {
        require(addr != address(0) && !_admin.contains(addr), "addr not alow");
        return _admin.add(addr);
    }

    function delAdmin(address addr) external onlyOwner returns (bool) {
        require(_admin.contains(addr), "address not in _admin");
        return _admin.remove(addr);
    }

    function admins() public view returns (address[] memory) {
        address[] memory values = new address[](_admin.length());
        for (uint256 i = 0; i < _admin.length(); ++i) {
            values[i] = _admin.at(i);
        }
        return values;
    }

    function transferOwner(address target, address newOwner) external onlyOwner {
        IGovernanceHub(target).transferOwnership(newOwner);
    }

    function transferGovernance(address target, address addr) external onlyOwner {
        IGovernanceHub(target).setGovernance(addr);
    }

    /**
     * ILiquidStaking
     */
    function addNodeBeneficiary(address target, address _beneficiary) external onlyOwner {
        IGovernanceHub(target).addBeneficiary(_beneficiary);
    }

    function delNodeBeneficiary(address target, address _beneficiary) external onlyAdmin {
        IGovernanceHub(target).delBeneficiary(_beneficiary);
    }

    function setTotalPoolFilLimit(address target, uint256 _limit) external onlyAdmin {
        IGovernanceHub(target).setTotalPoolFilLimit(_limit);
    }

    /**
     * IVault
     */
    function setRecipient(address target, address payable _recipient) external onlyOwner {
        IGovernanceHub(target).setRecipient(_recipient);
    }

    function setReserves(address target, uint256 _amount) external onlyOwner {
        IGovernanceHub(target).setReserves(_amount);
    }

    function setBeneficiaryFactory(address _beneficiaryFactoryAddress) external onlyOwner {
        require(_beneficiaryFactoryAddress != address(0), "BeneficiaryAndVaultFactory address invalid");
        emit BeneficiaryAndVaultFactoryChanged(beneficiaryFactoryAddress, _beneficiaryFactoryAddress);
        beneficiaryFactoryAddress = _beneficiaryFactoryAddress;
    }

    function setKinghashVaultContract(address _kinghashVaultContract) external onlyOwner {
        require(_kinghashVaultContract != address(0), "BeneficiaryAndVaultFactory address invalid");
        emit KinghashVaultContractChanged(kinghashVaultContract, _kinghashVaultContract);
        kinghashVaultContract = _kinghashVaultContract;
    }

    function setLiquidStakingContract(address _liquidStakingContract) external onlyOwner {
        require(_liquidStakingContract != address(0), "LiquidStaking address invalid");
        emit LiquidStakingChanged(liquidStakingContract, _liquidStakingContract);
        liquidStakingContract = _liquidStakingContract;
    }

    /**
     * IBeneficiary
     */
    function claimRewards(address target, bool needReward, uint256 _amount, bytes calldata params) external onlyAdmin {
        IGovernanceHub(target).claimRewards(needReward, _amount, params);
    }

    function depositFil(address target, uint256 to, uint256 amount) external onlyAdmin {
        IGovernanceHub(target).depositFil(to, amount);
    }

    function withdrawFil(address target, uint256 amount, bytes calldata params) external onlyAdmin {
        IGovernanceHub(target).withdrawFil(amount, params);
    }

    function claimBalanceRewards(address target, bool needReward) external onlyAdmin {
        IGovernanceHub(target).claimBalanceRewards(needReward);
    }

    function withdrawBalanceFil(address target) external onlyAdmin {
        IGovernanceHub(target).withdrawBalanceFil();
    }

    function setOperatorAndNode(address target, uint256 _operator, uint256 _nodeId) external onlyOwner {
        IGovernanceHub(target).setOperatorAndNode(_operator, _nodeId);
    }

    function setVaultPer(address target, uint256 _liquidStakingPer, uint256 _operatoVaultPer) external onlyAdmin {
        IGovernanceHub(target).setVaultPer(_liquidStakingPer, _operatoVaultPer);
    }

    function setKingHashVault(address target, address _vault) external onlyOwner {
        IGovernanceHub(target).setKingHashVault(_vault);
    }

    function setLiquidStaking(address target, address _liquidStaking) external onlyOwner {
        IGovernanceHub(target).setLiquidStaking(_liquidStaking);
    }

    function changeBeneficiary(address target, bytes memory params) external onlyAdmin {
        IGovernanceHub(target).changeBeneficiary(params);
    }

    function setLiquidStakingRewardAddress(address target, address newAddr) external onlyAdmin {
        IGovernanceHub(target).setLiquidStakingRewardAddress(newAddr);
    }

    function createBeneficiary(
        address _recipient,
        uint256 _reserves,
        uint256 _operatorVaultPer,
        uint256 _liquidStakingPer,
        uint256 _nodeId,
        uint256 _operator
    ) external onlyOwner {
        address vault = IBeneficiaryAndVaultFactory(beneficiaryFactoryAddress).createVault(_recipient, _reserves);

        address beneficiary = IBeneficiaryAndVaultFactory(beneficiaryFactoryAddress).createBeneficiary(
            kinghashVaultContract,
            vault,
            _operatorVaultPer,
            liquidStakingContract,
            _liquidStakingPer,
            _nodeId,
            _operator
        );

        IGovernanceHub(beneficiary).setLiquidStakingRewardAddress(msg.sender);
        IGovernanceHub(liquidStakingContract).addBeneficiary(beneficiary);
    }

    function multiCall(Call[] memory calls) public onlyOwner returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success);
            returnData[i] = ret;
        }
    }
}
