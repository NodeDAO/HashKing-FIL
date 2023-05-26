// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract StakingBase is OwnableUpgradeable {
    address public governance;

    modifier onlyGovernance() {
        require(owner() == msg.sender || governance == msg.sender, "caller is not allow");
        _;
    }

    function setGovernance(address gov) external onlyOwner {
        governance = gov;
    }
}
