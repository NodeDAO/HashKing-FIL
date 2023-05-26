// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "contracts/StakingBase.sol";
import "contracts/interfaces/INFIL.sol";
import "contracts/interfaces/IBeneficiary.sol";
import "contracts/library/NodeAPI.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

struct EquityPoint {
    uint256 blockNumber;
    uint256 value;
}

/**
 * @title LiquidStaking Contract
 */
contract LiquidStaking is StakingBase, UUPSUpgradeable {
    using SafeMath for uint256;
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;

    event FilStake(address indexed _from, uint256 _amount, uint256 _amountOut);
    event FilReward(address indexed _from, uint256 _amount);
    event FilMining(address indexed ben, uint256 indexed node, uint256 indexed to, uint256 _amount);
    event FilRepayment(address indexed _from, uint256 _amount);

    /**
     * @notice beneficiary contract list
     */
    EnumerableSet.AddressSet private beneficiary;

    /**
     * @notice NFIL contract
     */
    INFIL public nFilContract;

    /**
     * @notice total staking fil and reward fil
     */
    uint256 public totalPoolFil;

    /**
     * @notice total reward fil
     */
    uint256 public totalPoolProfit;

    /**
     * @notice staking pool limit , no limit if zero
     */
    uint256 public totalPoolFilLimit;

    /**
     * @notice last claim reward block number
     */
    uint256 public curProfitBlockNumber;

    /**
     * @notice totalPoolFil/INFIL.totalSupply(), init equityPoint[0].value = 1
     */
    EquityPoint[] public equityPoint;

    /**
     * @notice total staking fil by user
     */
    uint256 public totalStakeFil;

    /**
     * @notice max value that user can unstake
     */
    uint256 public totalUnStakeLimit;

    /**
     * @notice already unstake fil 
     */
    uint256 public totalUnStakeFil;

    event FilUnStake(address indexed _from, uint256 _amount, uint256 _amountOut);

    using Address for address payable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize(INFIL nFIL) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();

        require(address(nFIL) != address(0), "nfil address must != address(0)");
        nFilContract = nFIL;

        // init equity = 1
        equityPoint.push(EquityPoint({blockNumber: 0, value: 1e9}));
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier beneficiaryAuth() {
        require(beneficiary.contains(msg.sender), "invalid beneficiary");
        _;
    }

    /**
     * @notice add sp
     * @param addr beneficiary contract
     */
    function addBeneficiary(address addr) external onlyGovernance returns (bool) {
        require(addr != address(0), "address must != address(0)");
        require(!beneficiary.contains(addr), "address already in beneficiary");
        return beneficiary.add(addr);
    }

    /**
     * @notice remove sp
     * @param addr beneficiary contract
     */
    function delBeneficiary(address addr) external onlyGovernance returns (bool) {
        require(beneficiary.contains(addr), "address not in beneficiary");
        return beneficiary.remove(addr);
    }

    /**
     * @notice find all sp
     */
    function beneficiarys() public view returns (address[] memory) {
        address[] memory values = new address[](beneficiary.length());
        for (uint256 i = 0; i < beneficiary.length(); ++i) {
            values[i] = beneficiary.at(i);
        }
        return values;
    }

    function setTotalPoolFilLimit(uint256 _amount) external onlyGovernance {
        totalPoolFilLimit = _amount;
    }

    function setTotalUnStakeLimit(uint256 _amount) external onlyGovernance {
        totalUnStakeLimit = _amount;
    }

    /**
     * @notice stake fil to sp
     * @param amount stake amount
     */
    function depositFil(uint256 amount) external beneficiaryAuth {
        address _beneficiary = msg.sender;
        uint256 operator = IBeneficiary(_beneficiary).operator();
        uint256 nodeId = IBeneficiary(_beneficiary).nodeId();
        require(operator > 0, "address to not allow");
        uint256 bal = address(this).balance;
        require(amount > 0 && amount <= bal, "amount not allow");

        NodeAPI.send(uint64(operator), amount);
        emit FilMining(_beneficiary, nodeId, operator, amount);
    }

    /**
     * @notice unstake fil from sp
     */
    function repayment() external payable beneficiaryAuth {
        require(msg.value > 0, "value must > 0");
        emit FilRepayment(msg.sender, msg.value);
    }

    /**
     * @notice claim reward from sp
     */
    function claimRewards(bool) external payable beneficiaryAuth {
        require(msg.value > 0, "reward must > 0");
        uint256 amount = msg.value;
        totalPoolFil = amount.add(totalPoolFil);
        totalPoolProfit = totalPoolProfit.add(amount);
        emit FilReward(msg.sender, msg.value);

        if (block.number > curProfitBlockNumber) {
            curProfitBlockNumber = block.number;
            equityPoint.push(
                EquityPoint({blockNumber: block.number, value: totalPoolFil.mul(1e9).div(nFilContract.totalSupply())})
            );
            return;
        } else {
            EquityPoint storage ep = equityPoint[equityPoint.length - 1];
            ep.value = totalPoolFil.mul(1e9).div(nFilContract.totalSupply());
        }
    }

    /**
     * @notice stake fil to get nFil
     */
    function stakeFil() external payable {
        require(msg.value > 0 , "stake amount must > 0");
        uint256 depositPoolAmount = msg.value;
        uint256 amountOut = getNFilOut(depositPoolAmount);

        totalPoolFil = totalPoolFil.add(depositPoolAmount);
        totalStakeFil = totalStakeFil.add(depositPoolAmount);
        if (totalPoolFilLimit > 0) {
            require(totalPoolFilLimit >= totalPoolFil, "stake limit");
        }

        nFilContract.whiteListMint(amountOut, msg.sender);
        emit FilStake(msg.sender, msg.value, amountOut);
    }

    /**
     * @notice How much FIL can be obtained by trading NFIL
     * @param _amountIn the fil amount
     */
    function getNFilOut(uint256 _amountIn) public view returns (uint256) {
        return _amountIn;
    }

    /**
     * @notice How much nFil can be obtained by trading FIL
     * @param _amountIn the nFil amount
     */
    function getFilOut(uint256 _amountIn) public view returns (uint256) {
        return _amountIn;
    }

    function equityPointLength() public view returns (uint256) {
        return equityPoint.length;
    }

    /**
     * @notice get last n EquityPoint
     * @param len pick up EquityPoint len, if len > EquityPoint.length, return all EquityPoint
     */
    function lastEquityPoint(uint256 len) public view returns (EquityPoint[] memory) {
        if (len > equityPoint.length) {
            len = equityPoint.length;
        }

        EquityPoint[] memory values = new EquityPoint[](len);
        for (uint256 i = 1; i <= len; ++i) {
            values[len - i] = equityPoint[equityPoint.length - i];
        }
        return values;
    }
    
    function hasBeneficiary(address target) external view returns(bool){
        return beneficiary.contains(target);
    }

    /**
     * @notice nfil swap fil
     */
    function unStakeFil(uint amount) external {
        require(amount > 0 , "unstake amount must > 0");

        totalUnStakeFil = totalUnStakeFil.add(amount);
        require(totalUnStakeFil <= totalUnStakeLimit, "unstake balance limit");
        
        // burn nfil
        nFilContract.whiteListBurn(amount, msg.sender);

        // send fil
        uint256 amountOut = getFilOut(amount);
        payable(msg.sender).sendValue(amountOut);

        emit FilUnStake(msg.sender, amount, amountOut);
    }

    /**
     * @notice burn nfil without pay fil
     */
    function freeNFil(uint amount) external {
        require(amount > 0 , "unstake amount must > 0");
        totalUnStakeFil = totalUnStakeFil.add(amount);
        // burn nfil
        nFilContract.whiteListBurn(amount, msg.sender);
        emit FilUnStake(msg.sender, amount, 0);
    }
}
