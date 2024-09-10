// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MCTReward is Ownable {
    // using SafeERC20 library to handle token transfer.
    using SafeERC20 for IERC20;

    // Token used for reward.
    IERC20 public immutable rewardToken;

    uint256 public rewardRate = 25;

    uint256 private totalDistributedReward;

    event RewardPaid(address indexed user, uint256 reward);

    /**
     * @notice Set the ERC20 token which will be distributed.
     * @param _token The ERC20 token which will be distributed.
     */
    constructor(IERC20 _token) {
        // check whether the token is zero address or not.
        // If the address is zero, revert.
        require(address(_token) != address(0));

        rewardToken = _token;
    }

    function rewardDistribution(address _recipient, uint256 _amount, uint _numOfPassTest) external onlyOwner {
        require(_recipient != address(0) , "address must be non-zero");
        require(_amount > 0 ,"Amount must be greater than zero");
        require(_numOfPassTest > 0 && _numOfPassTest <= 10, "Passed test must be greter tahn zero and less than 10");

        uint256 totalRewardEarned = computeRewardAmount(_amount,_numOfPassTest);

        // transfer the tokens.
        rewardToken.safeTransfer(_recipient, totalRewardEarned);

        totalDistributedReward += totalRewardEarned;

        emit RewardPaid(_recipient, totalRewardEarned);

    }

    function rewardDistributionAirdrop(address[] calldata _recipients, uint256[] calldata _amounts, uint[] calldata _numOfPassTest) external onlyOwner {
        require((_recipients.length == _amounts.length) &&
            (_recipients.length == _numOfPassTest.length) &&
            (_amounts.length == _numOfPassTest.length), "params missmatch");

        for(uint256 i = 0; i < _recipients.length; i++){
            address recipient = _recipients[i];
            uint256 amount = _amounts[i];
            uint256 numOfPassTest = _numOfPassTest[i];

            require(recipient != address(0),"Receiver must be non-zero address");
            require (amount != 0, "Amount must be greater than zero");
            require(numOfPassTest > 0 && numOfPassTest <= 10, "Passed test must be greter tahn zero and less than 10");

            uint256 totalRewardEarned = computeRewardAmount(amount,numOfPassTest);
            // transfer the tokens.
            rewardToken.safeTransfer(recipient, totalRewardEarned);
            totalDistributedReward += totalRewardEarned;
            emit RewardPaid(recipient, totalRewardEarned);
        }

    }

    function withdrawTokens(address beneficiary) external onlyOwner {
        // fetch the contract token balance.
        uint256 tokenBalance = rewardToken.balanceOf(address(this));

        // if tokens are available, send them to the beneficiary address.
        if (tokenBalance != 0) {
            rewardToken.safeTransfer(beneficiary, tokenBalance);
        }
    }

    function computeRewardAmount(uint256 amount, uint numOfPassTest) internal view returns(uint256){
        uint256 reward = (amount * rewardRate)/100;
        uint256 totalReward = amount + reward;
        uint256 rewardEarned = (totalReward/10) * numOfPassTest;
        return rewardEarned;
    }

    function computeContractBalance() external view returns(uint256) {
        return rewardToken.balanceOf(address(this));
    }

    function totalRewardDistributed() external view returns (uint256) {
        return totalDistributedReward;
    }

}