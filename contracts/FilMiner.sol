// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {
    MinerAPI, MinerTypes, MinerCBOR, BigIntCBOR, BigInt
} from "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";

import "contracts/library/NodeAPI.sol";
import "contracts/interfaces/ILiquidStaking.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract FilMiner {
    using SafeMath for uint256;
    using Address for address;

    uint256 public testReturn;

    function getMinerBalance(uint64 miner) external returns (MinerTypes.GetAvailableBalanceReturn memory) {
        return MinerAPI.getAvailableBalance(miner);
    }

    function GetMinerOwner(uint64 miner) external returns (MinerTypes.GetOwnerReturn memory) {
        return MinerAPI.getOwner(miner);
    }

    function changeMinerOwner(uint64 miner, address addr) external returns (bool) {
        MinerAPI.changeOwnerAddress(miner, abi.encodePacked(addr));
        return true;
    }

    function withdrawBalance(uint64 miner, BigInt memory amount) external {
        MinerAPI.withdrawBalance(
            miner, MinerTypes.WithdrawBalanceParams({amount_requested: BigIntCBOR.serializeBigInt(amount)})
        );
    }

    function withdrawBalance1(uint64 miner, bytes memory amount) external {
        NodeAPI.withdrawBalance(miner, amount);
    }

    function withdrawBalance2(uint64 miner, bytes memory amount) external {
        uint256 beforeBal = address(this).balance;
        NodeAPI.withdrawBalance(miner, amount);
        uint256 afterBal = address(this).balance;
        uint256 _amount = afterBal.sub(beforeBal);
        payable(msg.sender).transfer(_amount);
    }

    function withdrawBalance3(uint64 miner, bytes memory amount, address liq, bool claim) external {
        uint256 beforeBal = address(this).balance;
        NodeAPI.withdrawBalance(miner, amount);
        uint256 afterBal = address(this).balance;
        uint256 _amount = afterBal.sub(beforeBal);
        ILiquidStaking(liq).claimRewards{value: _amount}(claim);
    }

    function send(uint64 toAddress, uint256 amount) external {
        NodeAPI.send(toAddress, amount);
    }

    function decodeParams(bytes memory params) public pure returns (MinerTypes.WithdrawBalanceReturn memory) {
        return MinerCBOR.deserializeWithdrawBalanceReturn(params);
    }

    function encodeParams(BigInt memory amount) public pure returns (bytes memory) {
        MinerTypes.WithdrawBalanceParams memory params =
            MinerTypes.WithdrawBalanceParams({amount_requested: BigIntCBOR.serializeBigInt(amount)});

        return MinerCBOR.serializeWithdrawBalanceParams(params);
    }

    function encodeWithdrawParams(bytes memory amount) public pure returns (bytes memory) {
        MinerTypes.WithdrawBalanceParams memory params = MinerTypes.WithdrawBalanceParams({
            amount_requested: BigIntCBOR.serializeBigInt(
                BigInt({
                    val: amount,
                    // 金额都是正数
                    neg: false
                })
                )
        });
        return MinerCBOR.serializeWithdrawBalanceParams(params);
    }

    function changeBeneficiary(uint64 miner, bytes memory params) external {
        NodeAPI.changeBeneficiary(miner, params);
    }

    function changeBeneficiary1(uint64 miner, bytes memory addr, bytes memory amount, uint64 epoch) public {
        MinerTypes.ChangeBeneficiaryParams memory params = MinerTypes.ChangeBeneficiaryParams({
            new_beneficiary: addr,
            new_expiration: epoch,
            new_quota: BigInt({
                val: amount,
                // 金额都是正数
                neg: false
            })
        });
        MinerAPI.changeBeneficiary(miner, params);
    }

    function encodeBeneficiaryParams(bytes memory addr, bytes memory amount, uint64 epoch)
        public
        pure
        returns (bytes memory)
    {
        MinerTypes.ChangeBeneficiaryParams memory params = MinerTypes.ChangeBeneficiaryParams({
            new_beneficiary: addr,
            new_expiration: epoch,
            new_quota: BigInt({
                val: amount,
                // 金额都是正数
                neg: false
            })
        });

        return MinerCBOR.serializeChangeBeneficiaryParams(params);
    }

    function bigByte(BigInt memory num) public pure returns (bytes memory) {
        return BigIntCBOR.serializeBigInt(num);
    }

    function toBytes(uint256 _num) public pure returns (bytes memory _ret) {
        assembly {
            _ret := mload(0x10)
            mstore(_ret, 0x20)
            mstore(add(_ret, 0x20), _num)
        }
    }

    function writeForGetReturn(uint256 i) public returns (uint256) {
        testReturn = i;
        return testReturn;
    }

    receive() external payable {}
}
