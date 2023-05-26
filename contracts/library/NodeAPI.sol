// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {MinerTypes, MinerCBOR, BytesCBOR, Actor, Misc} from "@zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol";

library NodeAPI {
    using MinerCBOR for *;
    using BytesCBOR for bytes;

    /// @notice withdraw available balance by node id
    /// @param target The miner actor id you want to interact with
    /// @param raw_request the cbor params you want to withdraw
    function withdrawBalance(uint64 target, bytes memory raw_request)
        internal
        returns (MinerTypes.WithdrawBalanceReturn memory)
    {
        bytes memory raw_response =
            Actor.callByID(target, MinerTypes.WithdrawBalanceMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);

        bytes memory result = Actor.readRespData(raw_response);

        return result.deserializeWithdrawBalanceReturn();
    }

    /// @notice transfer fil to account id
    /// @param actor_id The address (filecoin account ID) you want to send funds to
    function send(uint64 actor_id, uint256 amount) internal {
        bytes memory rawResponse = Actor.callByID(actor_id, 0, Misc.NONE_CODEC, new bytes(0), amount, false);

        bytes memory result = Actor.readRespData(rawResponse);
        require(result.length == 0, "unexpected response received");
    }

    function changeBeneficiary(uint64 target, bytes memory raw_request) internal {
        bytes memory raw_response =
            Actor.callByID(target, MinerTypes.ChangeBeneficiaryMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);

        bytes memory result = Actor.readRespData(raw_response);
        require(result.length == 0, "unexpected response received");
    }
}
