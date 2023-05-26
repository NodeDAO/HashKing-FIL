// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Msign Contract
 */
contract Msign {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    event Activate(address indexed sender, bytes32 id);
    event Execute(address indexed sender, bytes32 id);
    event Sign(address indexed sender, bytes32 id);
    event Enable(address indexed sender, address indexed account);
    event Disable(address indexed sender, address indexed account);
    event Cancel(address indexed sender, bytes32 id);
    event ThresholdChange(uint256 oldThreshold, uint256 newThreshold);
    event MinDelayChange(uint256 oldDuration, uint256 newDuration);
    event Ban(address indexed sender, bytes32 func);
    event UnBan(address indexed sender, bytes32 func);

    /**
     * @notice proposal struct
     */
    struct proposal_t {
        address code;
        bytes data;
        uint256 done;
        uint256 blockNumber;
        mapping(address => uint256) signers;
    }

    /**
     * @notice all proposal
     */
    mapping(bytes32 => proposal_t) public proposals;

    /**
     * @notice all signer
     */
    EnumerableSet.AddressSet private _signers;

    /**
     * @notice undone proposal
     */
    EnumerableSet.Bytes32Set private _undoneProposal;

    /**
     * @notice timelock white list
     */
    EnumerableSet.Bytes32Set private banFuncSet;

    uint256 public threshold;

    /**
     * @notice timelock delay block number
     */
    uint256 public minDelay;

    /**
     * @notice constructor Msign
     */
    constructor(uint256 _length, address[] memory _accounts) {
        require(_length >= 1, "Msign.Length not valid");
        require(_length == _accounts.length, "Msign.Args fault");
        for (uint256 i = 0; i < _length; ++i) {
            require(_signers.add(_accounts[i]), "Msign.Duplicate signer");
        }
        threshold = (_signers.length() / 2) + 1;
    }

    //single sign auth
    modifier ssignauth() {
        require(_signers.contains(msg.sender), "Msign.Invalid signer");
        _;
    }

    //multi sign auth
    modifier msignauth(bytes32 id) {
        require(mulsignweight(id) >= threshold, "Msign.Threshold unreached");
        _;
    }

    modifier timelock(bytes32 id) {
        require(getTimeExecute(id) <= block.number, "Msign.timelock unreached");
        _;
    }

    modifier auth() {
        require(msg.sender == address(this));
        _;
    }

    /**
     * @notice get proposal execute block number
     * @param id proposal id
     */
    function getTimeExecute(bytes32 id) public view returns (uint256) {
        uint256 b = proposals[id].blockNumber;
        bytes memory d = proposals[id].data;
        uint256 m = minDelay;
        if (isBanFunc(sig(d))) {
            //exec at nonce
            m = 0;
        }
        return b + m;
    }

    /**
     * @notice gen proposal hash
     */
    function gethash(address code, uint256 salt, bytes memory data) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(code, salt, data));
    }

    /**
     * @notice proposal active
     * @param code tarage call contract
     * @param data call data
     */
    function activate(address code, bytes memory data) public ssignauth returns (bytes32) {
        require(code != address(0), "Msign.Invalid args");
        require(data.length >= 4, "Msign.Invalid args");
        bytes32 _hash = gethash(code, block.number, data);
        proposals[_hash].code = code;
        proposals[_hash].data = data;
        proposals[_hash].blockNumber = block.number;

        _undoneProposal.add(_hash);
        emit Activate(msg.sender, _hash);
        return _hash;
    }

    /**
     * @notice call proposal data
     * @param id proposal id
     */
    function execute(bytes32 id) public msignauth(id) timelock(id) returns (bool success, bytes memory result) {
        require(proposals[id].done == 0, "Msign.Proposal has been remove or executed");
        proposals[id].done = 1;
        _undoneProposal.remove(id);

        (success, result) = proposals[id].code.call(proposals[id].data);
        require(success, "Msign.Execute fail");
        emit Execute(msg.sender, id);
    }

    /**
     * @notice approve proposal
     * @param id proposal id
     */
    function sign(bytes32 id) public ssignauth {
        require(proposals[id].signers[msg.sender] == 0, "Msign.Duplicate sign");
        proposals[id].signers[msg.sender] = 1;
        emit Sign(msg.sender, id);
    }

    /**
     * @notice add signer
     * @param account new signer address
     */
    function enable(address account) public auth {
        require(_signers.add(account), "Msign.Duplicate signer");
        emit Enable(msg.sender, account);
    }

    /**
     * @notice remove signer
     * @param account the signer address
     */
    function disable(address account) public auth {
        require(_signers.remove(account), "Msign.Disable nonexist");
        require(_signers.length() >= 1, "Msign.Invalid set");
        require(threshold <= _signers.length(), "threshold must <= signer length");
        emit Disable(msg.sender, account);
    }

    /**
     * @notice cancel proposal
     * @param id proposal id
     */
    function cancel(bytes32 id) public auth {
        require(proposals[id].done == 0, "Msign.Proposal has been remove or executed");
        proposals[id].done = 2;
        _undoneProposal.remove(id);
        emit Cancel(msg.sender, id);
    }

    /**
     * @notice set proposal approve threshold
     * @param _threshold approve threshold
     */
    function setThreshold(uint256 _threshold) public auth {
        require(_threshold > 0, "threshold must > 0");
        require(_threshold <= _signers.length(), "threshold must <= signer length");

        emit ThresholdChange(threshold, _threshold);
        threshold = _threshold;
    }

    /**
     * @notice set timelock delay number
     * @param _minDelay delay block number
     */
    function setMinDelay(uint256 _minDelay) public auth {
        emit MinDelayChange(minDelay, _minDelay);
        minDelay = _minDelay;
    }

    /**
     * @notice proposal weight
     * @param id proposal id
     */
    function mulsignweight(bytes32 id) public view returns (uint256) {
        uint256 _weights = 0;
        for (uint256 i = 0; i < _signers.length(); ++i) {
            _weights += proposals[id].signers[_signers.at(i)];
        }
        return _weights;
    }

    function signers() public view returns (address[] memory) {
        address[] memory values = new address[](_signers.length());
        for (uint256 i = 0; i < _signers.length(); ++i) {
            values[i] = _signers.at(i);
        }
        return values;
    }

    function signable(address signer) public view returns (bool) {
        return _signers.contains(signer);
    }

    /**
     * @notice undone proposal list
     */
    function unDoneIdList() public view returns (bytes32[] memory) {
        uint256 len = _undoneProposal.length();
        bytes32[] memory ret = new bytes32[](len);
        for (uint256 i = 0; i < len; i++) {
            ret[i] = _undoneProposal.at(i);
        }
        return ret;
    }

    /**
     * @notice check address is signer or had sign
     * @param signer user address
     * @param id proposal id
     */
    function canSign(address signer, bytes32 id) public view returns (bool) {
        if (_signers.contains(signer)) {
            proposal_t storage job = proposals[id];
            if (id == gethash(job.code, job.blockNumber, job.data) && job.done == 0) {
                return job.signers[signer] == 0;
            }
        }
        return false;
    }

    function isBanFunc(bytes4 func) public view returns (bool) {
        return banFuncSet.contains(func);
    }

    function banList() public view returns (bytes32[] memory) {
        uint256 len = banFuncSet.length();
        bytes32[] memory ret = new bytes32[](len);
        for (uint256 i = 0; i < len; i++) {
            ret[i] = banFuncSet.at(i);
        }
        return ret;
    }

    function ban(bytes4 func) public auth {
        require(banFuncSet.add(func), "ban function fail");
        emit Ban(msg.sender, func);
    }

    function unban(bytes4 func) public auth {
        require(banFuncSet.remove(func), "unban function fail");
        emit UnBan(msg.sender, func);
    }

    //https://docs.soliditylang.org/en/v0.6.12/types.html#bytes-and-strings-as-arrays
    function sig(bytes memory _payload) public pure returns (bytes4) {
        bytes4 _sig =
            _payload[0] | (bytes4(_payload[1]) >> 8) | (bytes4(_payload[2]) >> 16) | (bytes4(_payload[3]) >> 24);

        return _sig;
    }
}
