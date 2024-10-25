// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract StackingWithEthRewards {
    IERC20 public immutable stackingToken;
    uint256 public immutable rewardRate;

    constructor(address _stackingToken, uint256 _rewardRate) {
        stackingToken = IERC20(_stackingToken);
        rewardRate = _rewardRate;
    }

    mapping(address => uint256) lastClaimed;
    mapping(address => uint256) rewardDebt;
    mapping(address => uint256) public balances;

    function earned(address account) public view returns (uint256) {
        return
            rewardDebt[account] +
            (block.number - lastClaimed[account]) *
            rewardRate *
            balances[account];
    }

    function stake(uint256 amount) external {
        require(stackingToken.transferFrom(msg.sender, address(this), amount));
        uint256 currentBalance = balances[msg.sender];

        if (currentBalance != 0) {
            rewardDebt[msg.sender] = earned(msg.sender);
        }

        lastClaimed[msg.sender] = block.number;
        balances[msg.sender] = currentBalance + amount;
    }

    function withdraw(uint256 amount) external {
        uint256 currentBalance = balances[msg.sender];
        require(currentBalance >= amount);

        rewardDebt[msg.sender] = earned(msg.sender);
        lastClaimed[msg.sender] = block.number;
        balances[msg.sender] = currentBalance - amount;

        stackingToken.transfer(msg.sender, amount);
    }

    function getReward() external {
        uint256 earnedAmount = earned(msg.sender);
        require(earnedAmount > 0, "No reward");

        lastClaimed[msg.sender] = block.number;
        rewardDebt[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: earnedAmount}("");
        require(sent, "Unable to send");
    }

    function exit() external {
        uint256 earnedAmount = earned(msg.sender);
        if (earnedAmount > 0) {
            lastClaimed[msg.sender] = block.number;
            rewardDebt[msg.sender] = 0;
            (bool sent, ) = msg.sender.call{value: earnedAmount}("");
            require(sent, "Unable to send");
        }

        uint256 currentBalance = balances[msg.sender];
        if (currentBalance > 0) {
            balances[msg.sender] = 0;
            stackingToken.transfer(msg.sender, currentBalance);
        }
    }
}
