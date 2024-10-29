// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract Staking {
    address public immutable owner;
    bool public enabled = true;

    IERC20 public immutable stakingToken;
    IERC20 public immutable rewardToken;
    uint256 public rewardRate;

    struct Stake {
        uint256 lastComputedAt;
        uint256 computedReward;
        uint256 amount;
    }

    mapping(address => Stake) public stakes;

    event Staked(uint256 amount);
    event Unstaked(uint256 amount);
    event RewardRateChanged();
    event EnabledChanged();

    constructor(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRate
    ) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = (_rewardRate * 1 ether) / 365 days;
    }

    function setRewardRate(uint256 _rewardRate) external {
        require(msg.sender == owner);
        rewardRate = (_rewardRate * 1 ether) / 365 days;
        emit RewardRateChanged();
    }

    function setEnabled(bool _enabled) external {
        require(msg.sender == owner);
        enabled = _enabled;
        emit EnabledChanged();
    }

    function getTotalUnclaimedReward(
        address account
    ) public view returns (uint256) {
        Stake storage accountStake = stakes[account];
        return
            accountStake.computedReward +
            (block.timestamp - accountStake.lastComputedAt) * // elapsed seconds
            ((rewardRate * accountStake.amount) / 1 ether); // rewardRate is per second per 1 eth
    }

    function stake(uint256 amount) external {
        require(enabled);
        require(stakingToken.transferFrom(msg.sender, address(this), amount));
        Stake storage accountStake = stakes[msg.sender];

        if (accountStake.amount != 0) {
            accountStake.computedReward = getTotalUnclaimedReward(msg.sender);
        }

        accountStake.lastComputedAt = block.timestamp;
        accountStake.amount += amount;
        emit Staked(amount);
    }

    function unstake(uint256 amount) external {
        Stake storage accountStake = stakes[msg.sender];
        require(accountStake.amount >= amount);

        accountStake.computedReward = getTotalUnclaimedReward(msg.sender);
        accountStake.lastComputedAt = block.timestamp;
        accountStake.amount -= amount;

        stakingToken.transfer(msg.sender, amount);
        emit Unstaked(amount);
    }

    function claimReward() external {
        require(enabled);
        uint256 earnedAmount = getTotalUnclaimedReward(msg.sender);
        require(earnedAmount > 0);
        Stake storage accountStake = stakes[msg.sender];

        accountStake.lastComputedAt = block.timestamp;
        accountStake.computedReward = 0;

        rewardToken.transfer(msg.sender, earnedAmount);
    }

    function unstakeAndClaimReward() external {
        Stake storage accountStake = stakes[msg.sender];
        if (enabled) {
            uint256 rewardAmount = getTotalUnclaimedReward(msg.sender);
            if (rewardAmount > 0) {
                accountStake.lastComputedAt = block.timestamp;
                accountStake.computedReward = 0;
                rewardToken.transfer(msg.sender, rewardAmount);
            }
        }

        if (accountStake.amount > 0) {
            uint256 amount = accountStake.amount;
            accountStake.amount = 0;

            stakingToken.transfer(msg.sender, amount);
            emit Unstaked(amount);
        }
    }
}
