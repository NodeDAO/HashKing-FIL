// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/interfaces/INFIL.sol";
import "contracts/StakingBase.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * @title NFIL Contract
 */
contract NFIL is INFIL, OwnableUpgradeable, ERC20Upgradeable, UUPSUpgradeable {
    address public liquidStakingContractAddress;

    modifier onlyLiquidStaking() {
        require(liquidStakingContractAddress == msg.sender, "Not allowed to touch funds");
        _;
    }

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC20_init("Node FIL", "NFIL");
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @notice set LiquidStaking contract address
     * @param _liquidStakingContractAddress liquidStaking address
     */
    function setLiquidStaking(address _liquidStakingContractAddress) external onlyOwner {
        require(_liquidStakingContractAddress != address(0), "LiquidStaking address invalid");
        emit LiquidStakingContractSet(liquidStakingContractAddress, _liquidStakingContractAddress);
        liquidStakingContractAddress = _liquidStakingContractAddress;
    }

    /**
     * @notice mint NFIL
     * @param _amount mint amount
     * @param _account mint account
     */
    function whiteListMint(uint256 _amount, address _account) external onlyLiquidStaking {
        _mint(_account, _amount);
    }

    /**
     * @notice burn NFIL
     * @param _amount burn amount
     * @param _account burn account
     */
    function whiteListBurn(uint256 _amount, address _account) external onlyLiquidStaking {
        _burn(_account, _amount);
    }
}
