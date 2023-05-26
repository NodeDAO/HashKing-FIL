// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/StakingBase.sol";
import "contracts/interfaces/IVault.sol";

/**
 * @title Vault Contract
 *
 * dao vault and node miner vault
 */
contract Vault is StakingBase, IVault {
    using SafeMath for uint256;
    using Address for address payable;

    event Reward(address indexed _recipient, uint256 _amount);
    event Received(address indexed _from, uint256 _amount);

    /**
     * @notice who's owner the fund
     */
    address payable public recipient;

    /**
     * @notice locked fund
     */
    uint256 public reserves;

    /**
     * @notice all in come fund, include reserves fund
     */
    uint256 public totalReward;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize(address _recipient, uint256 _reserves) public initializer {
        __Ownable_init();

        recipient = payable(_recipient);
        reserves = _reserves;
    }

    /**
     * @notice claim reward from filecoin node available balance
     * @param needReward automatic send fund to recipient address if true
     */
    function claimRewards(bool needReward) external payable {
        uint256 amount = msg.value;
        if (amount > 0) {
            totalReward += amount;
            emit Received(msg.sender, amount);
        }

        if (needReward && address(0) != recipient) {
            uint256 bal = address(this).balance;
            if (bal > reserves) {
                uint256 reward = bal.sub(reserves);
                recipient.sendValue(reward);
                emit Reward(recipient, reward);
            }
        }
    }

    /**
     * @notice set recipient address
     */
    function setRecipient(address payable _recipient) external onlyGovernance {
        recipient = _recipient;
    }

    /**
     * @notice set reserves fund
     */
    function setReserves(uint256 _reserves) external onlyGovernance {
        reserves = _reserves;
    }
}
