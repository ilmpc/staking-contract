// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract StackingWithOwner {
    address public immutable owner;
    bool public enabled = true;
    uint256 public totalStacked = 0;

    IERC20 public immutable stackingToken;
    IERC20 public immutable rewardToken;
    uint256 public rewardRate;

    constructor(address _stackingToken, address _rewardToken, uint256 _rewardRate) {
        owner = msg.sender;
        stackingToken = IERC20(_stackingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
    }

    mapping(address => uint256) lastClaimed;
    mapping(address => uint256) rewardDebt;
    mapping(address => uint256) public balances;

    function changeRewardRate(uint256 rate) external {
        require(msg.sender == owner);
        rewardRate = rate;
    }

    function changeEnabled(bool state) external {
        require(msg.sender == owner);
        enabled = state;
    }

    function earned(address account) public view returns (uint256) {
        return rewardDebt[account] + (block.number - lastClaimed[account]) * rewardRate * balances[account];
    }

    function stake(uint256 amount) external {
        require(enabled);
        require(stackingToken.transferFrom(msg.sender, address(this), amount));
        uint256 currentBalance = balances[msg.sender];

        if (currentBalance != 0) {
            rewardDebt[msg.sender] = earned(msg.sender);
        }

        lastClaimed[msg.sender] = block.number;
        balances[msg.sender] = currentBalance + amount;
        totalStacked += amount;
    }

    function withdraw(uint256 amount) external {
        uint256 currentBalance = balances[msg.sender];
        require(currentBalance >= amount);

        rewardDebt[msg.sender] = earned(msg.sender);
        lastClaimed[msg.sender] = block.number;
        balances[msg.sender] = currentBalance - amount;

        stackingToken.transfer(msg.sender, amount);
        totalStacked -= amount;
    }

    function getReward() external {
        require(enabled);
        uint256 earnedAmount = earned(msg.sender);
        require(earnedAmount > 0);

        lastClaimed[msg.sender] = block.number;
        rewardDebt[msg.sender] = 0;

        rewardToken.transfer(msg.sender, earnedAmount);
    }

    function exit() external {
        if (enabled) {
            uint256 rewardAmount = earned(msg.sender);
            if (rewardAmount > 0) {
                lastClaimed[msg.sender] = block.number;
                rewardDebt[msg.sender] = 0;
                rewardToken.transfer(msg.sender, rewardAmount);
            }
        }

        uint256 currentBalance = balances[msg.sender];
        if (currentBalance > 0) {
            balances[msg.sender] = 0;
            stackingToken.transfer(msg.sender, currentBalance);
            totalStacked -= currentBalance;
        }
    }
}
