// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/StakingBase.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title stake pool info
 */
struct PoolInfo {
    IERC20 token;
    uint256 lastRewardBlock;
    uint256 accPerShare;
    uint256 accShare;
    uint256 totalAmount;
    uint256 totalAmountLimit;
    uint256 blockReward;
    uint64 fee;
}

// Info of each user.
struct UserInfo {
    uint256 amount;
    uint256 debt;
    // pending reward
    uint256 reward;
    uint256 lastDepostBlock;
}

interface IController {
    function withdraw(address _token, uint _amount) external;
    function earn(address _token) external;
    function withdrawPending(
        address token,
        address user,
        uint256 userPending
    ) external returns (bool);
}

contract HubPool is StakingBase, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    function initialize() public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        paused = false;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier checkToken(address token) {
        require(
            token != address(0) && address(poolInfo[TokenOfPid[token]].token) == token,
            "token not exists"
        );
        _;
    }

    modifier notPause() {
        require(paused == false, "Mining has been suspended");
        _;
    }

    bool public paused; 

    address public controller;

    PoolInfo[] public poolInfo;

    mapping(address => uint256) public TokenOfPid;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    uint256 public userTotalProfit;

    uint256 public userTotalSendProfit;

    function checkGovernance() private view onlyGovernance {}

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function getPoolInfo(address token) internal view checkToken(token) returns (PoolInfo storage) {
        return poolInfo[TokenOfPid[token]];
    }

    function getPoolId(address token) public view checkToken(token) returns (uint256) {
        return TokenOfPid[token];
    }

    function setTotalAmountLimit(address token, uint256 _limit) public {
        checkGovernance();
        PoolInfo storage pool = getPoolInfo(token);
        pool.totalAmountLimit = _limit;
    }

    function setPoolFee(address token, uint64 _fee) public {
        checkGovernance();
        PoolInfo storage pool = getPoolInfo(token);
        pool.fee = _fee;
    }

    function setController(address _controller) public {
        require(_controller != address(0), "controller is the zero address");
        checkGovernance();
        controller = _controller;
    }

    function setPause() public {
        require(msg.sender == owner() || msg.sender == governance, "not allow");
        paused = !paused;
    }

    function setBlockReward(address token, uint256 _reward, bool _withUpdate) public {
        checkGovernance();
        PoolInfo storage pool = getPoolInfo(token);
        if (_withUpdate) {
            massUpdatePools();
        }
        pool.blockReward = _reward;
    }

    function approveCtr(address token) public {
        IERC20(token).safeApprove(controller, uint256(0));
        IERC20(token).safeApprove(controller, type(uint).max);
    }

    function add(IERC20 _token, uint256 _totalAmountLimit, bool _withUpdate) public {
        require(address(_token) != address(0), "token is the zero address");
        checkGovernance();

        if (_withUpdate) {
            massUpdatePools();
        }

        poolInfo.push(
            PoolInfo({
                token: _token,
                lastRewardBlock: block.number,
                accPerShare: 0,
                accShare: 0,
                totalAmount: 0,
                totalAmountLimit: _totalAmountLimit,
                blockReward: 0,
                fee: 0
            })
        );
        TokenOfPid[address(_token)] = poolLength() - 1;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        updatePoolInfo(pool);
        pool.lastRewardBlock = block.number;
    }

    function updatePoolInfo(PoolInfo storage pool) internal {
        if (pool.blockReward <= 0 || pool.totalAmount == 0) {
            return;
        }

        uint256 blockReward = pool.blockReward.mul(block.number.sub(pool.lastRewardBlock));
        userTotalProfit = userTotalProfit.add(blockReward);
        pool.accShare = pool.accShare.add(blockReward);
        pool.accPerShare = blockReward.mul(1e18).div(pool.totalAmount).add(pool.accPerShare);
    }

    /**
     * @notice user pending reward
     */
    function pending(uint256 _pid, address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        PoolInfo storage pool = poolInfo[_pid];
        if (user.amount == 0 || pool.totalAmount == 0) {
            return 0;
        }

        uint256 blockPerReward = pool.blockReward.mul(block.number.sub(pool.lastRewardBlock)).mul(1e18).div(
            pool.totalAmount
        );
        uint256 accPerShare = pool.accPerShare.add(blockPerReward).sub(user.debt);
        return user.amount.mul(accPerShare).div(1e18).add(user.reward);
    }

    function depositWithPid(uint256 _pid, uint256 _amount) public notPause {
        require(_amount >= 0, "deposit: not good");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (pool.totalAmountLimit > 0) {
            require(
                pool.totalAmountLimit >= (pool.totalAmount.add(_amount)),
                "deposit amount limit"
            );
        }

        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pendingAmount = pending(_pid, msg.sender);
            user.reward = pendingAmount;
        }

        if (_amount > 0) {
            uint256 beforeToken = pool.token.balanceOf(address(this));
            pool.token.safeTransferFrom(msg.sender, address(this), _amount);
            uint256 afterToken = pool.token.balanceOf(address(this));
            uint transfAmount = afterToken.sub(beforeToken);
            require(transfAmount == _amount, "transfer amount do not eq deposit amount");

            if (_amount > 0) {
                user.amount = user.amount.add(_amount);
                pool.totalAmount = pool.totalAmount.add(_amount);
            }
            user.lastDepostBlock = block.number;
        }

        earn(address(pool.token));
        user.debt = pool.accPerShare;
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdrawWithPid(uint256 _pid, uint256 _amount) public notPause {
        require(_amount >= 0, "withdraw: not good");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: Insufficient balance");
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pendingAmount = pending(_pid, msg.sender);
            user.reward = 0;
            safeTransfer(address(pool.token), msg.sender, pendingAmount);
        }

        if (_amount > 0) {
            uint256 poolBalance = pool.token.balanceOf(address(this));
            if (poolBalance < _amount) {
                IController(controller).withdraw(address(pool.token), _amount.sub(poolBalance));
                poolBalance = pool.token.balanceOf(address(this));
                require(poolBalance >= _amount, "withdraw: need hedge");
            }

            user.amount = user.amount.sub(_amount);
            pool.totalAmount = pool.totalAmount.sub(_amount);
            pool.token.safeTransfer(msg.sender, _amount);
        }

        earn(address(pool.token));
        user.debt = pool.accPerShare;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function emergencyWithdraw(uint256 _pid) public notPause {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;

        uint256 poolBalance = pool.token.balanceOf(address(this));
        if (poolBalance < amount) {
            IController(controller).withdraw(address(pool.token), amount.sub(poolBalance));
            poolBalance = pool.token.balanceOf(address(this));
            require(poolBalance >= amount, "withdraw: need hedge");
        }

        user.amount = 0;
        user.debt = 0;
        user.reward = 0;
        pool.totalAmount = pool.totalAmount.sub(amount);

        pool.token.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    function safeTransfer(address _token, address _to, uint256 _userPendingAmount) private {
        if (_userPendingAmount > 0) {
            userTotalSendProfit = userTotalSendProfit.add(_userPendingAmount);
            IController(controller).withdrawPending(_token, _to, _userPendingAmount);
        }
    }

    function earn(address token) public {
        approveCtr(token);
        IController(controller).earn(token);
    }

    function getApy(address token) external view returns (uint256) {
        PoolInfo storage pool = getPoolInfo(token);
        //86400*365/30
        return pool.blockReward.mul(10000).mul(1051200).div(pool.totalAmount.add(1));
    }

    function deposit(address token, uint256 _amount) external {
        uint _pid = getPoolId(token);
        return depositWithPid(_pid, _amount);
    }

    function depositAll(address token) external {
        uint _pid = getPoolId(token);
        return depositWithPid(_pid, IERC20(token).balanceOf(msg.sender));
    }

    function withdraw(address token, uint256 _amount) external {
        uint _pid = getPoolId(token);
        return withdrawWithPid(_pid, _amount);
    }

    function withdrawAll(address token) external {
        uint _pid = getPoolId(token);
        UserInfo storage user = userInfo[_pid][msg.sender];
        return withdrawWithPid(_pid, user.amount);
    }
}
