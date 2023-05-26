// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {
    MinerAPI, MinerTypes, MinerCBOR, BigIntCBOR, BigInt
} from "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";
import "contracts/interfaces/IBeneficiary.sol";
import "contracts/interfaces/ILiquidStaking.sol";
import "contracts/StakingBase.sol";
import "contracts/library/NodeAPI.sol";

/**
 * @title Beneficiary Contract
 *
 * the filecoin blockchain sp beneficiary
 */
contract Beneficiary is IBeneficiary, StakingBase {
    using SafeMath for uint256;
    using Address for address;

    event Received(address indexed _from, uint256 _amount);
    event Claims(uint256 kingHashReward, uint256 operatoReward, uint256 liquidStakingReward);

    uint256 public constant tenThousand = 10000;

    /**
     * @notice kingHash vault contract
     */
    address public kingHashVault;

    /**
     * @notice kingHash total reward claim
     */
    uint256 public totalKingHashVaultReward;

    /**
     * @notice sp vault contract
     */
    address public operatoVault;

    /**
     * @notice sp reward percent, scale 10000
     */
    uint256 public operatoVaultPer;

    /**
     * @notice sp total reward claim
     */
    uint256 public totalOperatoVaultReward;

    /**
     * @notice sp node account id
     */
    uint256 public nodeId;

    /**
     * @notice ap node account id or worker id
     */
    uint256 public operator;

    /**
     * @notice LiquidStaking contract
     */
    address public liquidStaking;

    /**
     * @notice LiquidStaking reward percent, scale 10000
     */
    uint256 public liquidStakingPer;

    /**
     * @notice LiquidStaking total reward
     */
    uint256 public totalLiquidStakingReward;

    /**
     * @notice total fil deposit to operator address
     */
    uint256 public totalStakingFil;

    /**
     * @notice LiquidStaking reward contract
     */
    address public liquidStakingRewardAddress;

    using Address for address payable;

    function initialize(
        address _kingHashVault,
        address _operatoVault,
        uint256 _operatoVaultPer,
        address _liquidStaking,
        uint256 _liquidStakingPer,
        uint256 _nodeId,
        uint256 _operator
    ) public initializer {
        __Ownable_init();

        require(_kingHashVault != address(0), "_kingHashVault is zero");
        require(_operatoVault != address(0), "_operatoVault is zero");
        require(_liquidStaking != address(0), "_liquidStaking is zero");
        require(_operatoVaultPer <= tenThousand, "_operatoVaultPer must <= 10000");

        require(_liquidStakingPer <= tenThousand, "_liquidStakingPer must <= 10000");

        kingHashVault = _kingHashVault;
        operatoVault = _operatoVault;
        operatoVaultPer = _operatoVaultPer;
        liquidStaking = _liquidStaking;
        liquidStakingPer = _liquidStakingPer;
        nodeId = _nodeId;
        operator = _operator;
    }

    /**
     * @notice withdraw sp node available balance for reward to sp and LiquidStaking
     * @param needReward  automatic send fund to vault recipient address if true
     * @param _amount  sp reward
     * @param params withdrawBalance params cbor serialize data
     */
    function claimRewards(bool needReward, uint256 _amount, bytes calldata params) external {
        require(_amount > 0, "_amount must > 0");
        uint256 beforeBal = address(this).balance;
        // call node api by sp id
        NodeAPI.withdrawBalance(uint64(nodeId), params);

        uint256 afterBal = address(this).balance;
        uint256 amount = afterBal.sub(beforeBal);
        require(amount == _amount, "invalid amount");
        _claimRewards(needReward, amount);
    }

    function claimBalanceRewards(bool needReward) external {
        uint256 amount = address(this).balance;
        _claimRewards(needReward, amount);
    }

    function _claimRewards(bool needReward, uint256 amount) private onlyGovernance {
        require(amount > 0, "amount must > 0");
        // sp reward
        uint256 _totalOperatoVaultReward = amount.mul(operatoVaultPer).div(tenThousand);

        uint256 _plantReward = amount.sub(_totalOperatoVaultReward);
        // LiquidStaking reward
        uint256 _totalLiquidStakingReward = _plantReward.mul(liquidStakingPer).div(tenThousand);
        // dao reward
        uint256 _totalKingHashVaultReward = _plantReward.sub(_totalLiquidStakingReward);

        if (_totalKingHashVaultReward > 0) {
            require(kingHashVault != address(0), "kingHashVault is zero");
            totalKingHashVaultReward = totalKingHashVaultReward.add(_totalKingHashVaultReward);
            ILiquidStaking(kingHashVault).claimRewards{value: _totalKingHashVaultReward}(false);
        }

        if (_totalOperatoVaultReward > 0) {
            require(operatoVault != address(0), "operatoVault is zero");
            totalOperatoVaultReward = totalOperatoVaultReward.add(_totalOperatoVaultReward);
            ILiquidStaking(operatoVault).claimRewards{value: _totalOperatoVaultReward}(needReward);
        }

        if (_totalLiquidStakingReward > 0) {
            require(liquidStakingRewardAddress != address(0), "liquidStakingRewardAddress is zero");
            totalLiquidStakingReward = totalLiquidStakingReward.add(_totalLiquidStakingReward);
            //ILiquidStaking(liquidStaking).claimRewards{value: _totalLiquidStakingReward}(false);
            payable(liquidStakingRewardAddress).sendValue(_totalLiquidStakingReward);
        }
        emit Claims(_totalKingHashVaultReward, _totalOperatoVaultReward, _totalLiquidStakingReward);
    }

    /**
     * @notice deposit LiquidStaking fil to sp node
     * @param to sp node account id
     * @param amount deposit amount
     */
    function depositFil(uint256 to, uint256 amount) external onlyGovernance {
        require(to == operator && operator > 0, "address to not allow");
        ILiquidStaking(liquidStaking).depositFil(amount);
        totalStakingFil = totalStakingFil.add(amount);
    }

    /**
     * @notice withdraw sp node available balance for unstaking
     * @param amount unstaking amount
     * @param params withdrawBalance params cbor serialize data
     */
    function withdrawFil(uint256 amount, bytes calldata params) external {
        require(amount > 0, "amount must > 0");
        uint256 beforeBal = address(this).balance;
        // call node api by sp account id
        NodeAPI.withdrawBalance(uint64(nodeId), params);

        uint256 afterBal = address(this).balance;
        uint256 _amount = afterBal.sub(beforeBal);
        require(amount == _amount, "invalid amount");
        _withdrawFil(amount);
    }

    function withdrawBalanceFil() external {
        uint256 amount = address(this).balance;
        _withdrawFil(amount);
    }

    function _withdrawFil(uint256 amount) private onlyGovernance {
        require(amount > 0, "amount must > 0");
        ILiquidStaking(liquidStaking).repayment{value: amount}();
        totalStakingFil = totalStakingFil.sub(amount);
    }

    function setOperatorAndNode(uint256 _operator, uint256 _nodeId) external onlyGovernance {
        operator = _operator;
        nodeId = _nodeId;
    }

    function setVaultPer(uint256 _liquidStakingPer, uint256 _operatoVaultPer) external onlyGovernance {
        require(_operatoVaultPer <= tenThousand, "_operatoVaultPer must <= 10000");

        require(_liquidStakingPer <= tenThousand, "_liquidStakingPer must <= 10000");
        liquidStakingPer = _liquidStakingPer;
        operatoVaultPer = _operatoVaultPer;
    }

    function setKingHashVault(address _vault) external onlyGovernance {
        kingHashVault = _vault;
    }

    function setOperatoVault(address _vault) external onlyGovernance {
        operatoVault = _vault;
    }

    function setLiquidStaking(address _liquidStaking) external onlyGovernance {
        liquidStaking = _liquidStaking;
    }

    function setLiquidStakingRewardAddress(address _liquidStakingRewardAddress) external onlyGovernance {
        liquidStakingRewardAddress = _liquidStakingRewardAddress;
    }

    /**
     * @notice cbor encode node withdraw balance params
     * @param amount the sp node available amount
     */
    function withdrawBalanceParams(bytes memory amount) public pure returns (bytes memory) {
        MinerTypes.WithdrawBalanceParams memory params = MinerTypes.WithdrawBalanceParams({
            amount_requested: BigIntCBOR.serializeBigInt(BigInt({val: amount, neg: false}))
        });
        return MinerCBOR.serializeWithdrawBalanceParams(params);
    }

    /**
     * @notice cbor encode node change beneficiary params
     * @param addr    filecoin address payload hex
     * @param  amount uint quota
     * @param epoch expiration block count
     */
    function changeBeneficiaryParams(bytes memory addr, bytes memory amount, uint64 epoch)
        public
        pure
        returns (bytes memory)
    {
        MinerTypes.ChangeBeneficiaryParams memory params = MinerTypes.ChangeBeneficiaryParams({
            new_beneficiary: addr,
            new_expiration: epoch,
            new_quota: BigInt({val: amount, neg: false})
        });

        return MinerCBOR.serializeChangeBeneficiaryParams(params);
    }

    function changeBeneficiary(bytes memory params) public onlyGovernance {
        NodeAPI.changeBeneficiary(uint64(nodeId), params);
    }
}
