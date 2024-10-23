// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract Stacking {
    // address immutable owner;
    // bool enabled;
    IERC20 immutable stackingToken;
    IERC20 immutable rewardToken;
    uint256 rewardRate;

    constructor(address _stackingToken, address _rewardToken, uint256 _rewardRate) {
        // this.owner = msg.sender;
        stackingToken = IERC20(_stackingToken);
        rewardToken = IERC20(_rewardToken);
        rewardRate = _rewardRate;
    }

    mapping(address => uint256) lastClaimed;
    mapping(address => uint256) rewardDebt;
    mapping(address => uint256) public balances;

    function earned(address account) public view returns (uint256) {
        uint256 blocksPassed = block.number - lastClaimed[account];
        return rewardDebt[account] + blocksPassed * rewardRate * balances[account];
    }

    function stake(uint256 amount) external {
        require(stackingToken.transferFrom(msg.sender, address(this), amount));

        if (balances[msg.sender] != 0) {
            rewardDebt[msg.sender] = earned(msg.sender);
        }

        lastClaimed[msg.sender] = block.number;
        balances[msg.sender] += amount;
    }

    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount);

        rewardDebt[msg.sender] = earned(msg.sender);
        lastClaimed[msg.sender] = block.number;

        balances[msg.sender] -= amount;
        stackingToken.transfer(msg.sender, amount);
    }

    function getReward() external {
        uint256 amount = earned(msg.sender);
        require(amount > 0);
        lastClaimed[msg.sender] = block.number;
        rewardDebt[msg.sender] = 0;
        rewardToken.transfer(msg.sender, amount);
    }

    function exit() external {
        uint256 rewardAmount = earned(msg.sender);
        if (rewardAmount > 0) {
            lastClaimed[msg.sender] = block.number;
            rewardDebt[msg.sender] = 0;
            rewardToken.transfer(msg.sender, rewardAmount);
        }
        if (balances[msg.sender] > 0) {
            stackingToken.transfer(msg.sender, balances[msg.sender]);
            balances[msg.sender] = 0;
        }
    }
}
