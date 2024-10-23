// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Stacking} from "../src/Stacking.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract MintableMockERC20 is MockERC20 {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract StackingTest is Test {
    Stacking public staking;
    MintableMockERC20 public stakingToken;
    MintableMockERC20 public rewardToken;

    address alice = makeAddr("alice");
    uint256 constant INITIAL_BALANCE = 10 ether;
    uint256 constant REWARD_RATE = 10 wei;

    function setUp() public {
        // Deploy mock tokens
        stakingToken = new MintableMockERC20();
        stakingToken.initialize("Staking Token", "STK", 18);
        rewardToken = new MintableMockERC20();
        rewardToken.initialize("Reward Token", "RWD", 18);

        // Deploy staking contract
        staking = new Stacking(address(stakingToken), address(rewardToken), REWARD_RATE);

        // Setup initial balances
        stakingToken.mint(alice, INITIAL_BALANCE);
        rewardToken.mint(address(staking), INITIAL_BALANCE * 1e5); // Reward pool

        // Approve staking contract
        vm.prank(alice);
        stakingToken.approve(address(staking), type(uint256).max);
    }

    function test_Stake() public {
        uint256 stakeAmount = 5 ether;

        vm.prank(alice);
        staking.stake(stakeAmount);

        assertEq(staking.balances(alice), stakeAmount);
        assertEq(stakingToken.balanceOf(address(staking)), stakeAmount);
    }

    function test_MultipleStakes() public {
        uint256 firstStake = 5 ether;
        uint256 secondStake = 3 ether;

        vm.startPrank(alice);
        staking.stake(firstStake);

        // Simulate blocks passing
        vm.roll(block.number + 10);

        staking.stake(secondStake);
        vm.stopPrank();

        assertEq(staking.balances(alice), firstStake + secondStake);
        assertTrue(staking.earned(alice) > 0);
    }

    function test_Withdraw() public {
        uint256 stakeAmount = 10 ether;

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        vm.roll(block.number + 10);

        staking.withdraw(stakeAmount);
        vm.stopPrank();

        assertEq(staking.balances(alice), 0);
        assertTrue(staking.earned(alice) > 0);
        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
    }

    function test_GetReward() public {
        uint256 stakeAmount = 10 ether;

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        // Simulate time passing
        vm.roll(block.number + 10);

        uint256 expectedReward = staking.earned(alice);
        staking.getReward();
        vm.stopPrank();

        assertEq(rewardToken.balanceOf(alice), expectedReward);
        assertEq(staking.earned(alice), 0);
    }

    function test_Exit() public {
        uint256 stakeAmount = 5 ether;

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        vm.roll(block.number + 10);

        uint256 expectedReward = staking.earned(alice);
        staking.exit();
        vm.stopPrank();

        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
        assertEq(rewardToken.balanceOf(alice), expectedReward);
        assertEq(staking.balances(alice), 0);
        assertEq(staking.earned(alice), 0);
    }

    function test_RevertIf_WithdrawTooMuch() public {
        uint256 stakeAmount = 10 ether;

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        vm.expectRevert();
        staking.withdraw(stakeAmount + 1 ether);
        vm.stopPrank();
    }

    function test_RevertIf_GetRewardWithoutEarnings() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.getReward();
    }
}
