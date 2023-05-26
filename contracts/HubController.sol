// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract HubController is Ownable {
    using SafeERC20 for IERC20;
    address public vaults;
    event Reward(address indexed token, address indexed user, uint256 userPending);

    function setVault(address _vault) public onlyOwner {
        require(_vault != address(0), "vault address is zero");
        vaults = _vault;
    }

    function withdraw(address _token, uint _amount) public {}

    function earn(address _token) public {}

    function withdrawPending(
        address token,
        address user,
        uint256 userPending
    ) public returns (bool) {
        require(msg.sender == vaults || msg.sender == owner(), "!vault");
        require(address(0) != user, "user address is zero");
        if (userPending > 0) {
            payable(user).transfer(userPending);
            emit Reward(token, user, userPending);
        }
        return true;
    }

     function inCaseTokensGetStuck(address account, address _token, uint _amount) public { 
        require(msg.sender == owner(), "not allow!");
        IERC20(_token).safeTransfer(account, _amount);
    }

    receive() payable external {}
}
