// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {StackingWithOwner} from "../src/StackingWithOwner.sol";
import {MockERC20 as ERC20} from "forge-std/mocks/MockERC20.sol";

contract MockERC20 is ERC20 {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract StackingWithOwnerTest is Test {
    StackingWithOwner public staking;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    address public owner;
    address public alice;
    address public bob;
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant REWARD_RATE = 10 wei;

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy mock tokens
        stakingToken = new MockERC20();
        stakingToken.initialize("Staking Token", "STK", 18);
        rewardToken = new MockERC20();
        rewardToken.initialize("Reward Token", "RWD", 18);

        // Deploy staking contract
        staking = new StackingWithOwner(address(stakingToken), address(rewardToken), REWARD_RATE);

        // Setup initial balances
        stakingToken.mint(alice, INITIAL_BALANCE);
        stakingToken.mint(bob, INITIAL_BALANCE);
        rewardToken.mint(address(staking), INITIAL_BALANCE * 10); // Enough rewards

        // Approve staking contract
        vm.prank(alice);
        stakingToken.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        stakingToken.approve(address(staking), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(staking.owner(), owner);
        assertEq(address(staking.stackingToken()), address(stakingToken));
        assertEq(address(staking.rewardToken()), address(rewardToken));
        assertEq(staking.rewardRate(), REWARD_RATE);
        assertTrue(staking.enabled());
        assertEq(staking.totalStacked(), 0);
    }

    function test_Stake() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        assertEq(staking.balances(alice), stakeAmount);
        assertEq(staking.totalStacked(), stakeAmount);
        assertEq(stakingToken.balanceOf(address(staking)), stakeAmount);
    }

    function test_StakeWhenDisabled() public {
        vm.prank(owner);
        staking.changeEnabled(false);

        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        vm.expectRevert();
        staking.stake(stakeAmount);
    }

    function test_Withdraw() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.prank(alice);
        staking.withdraw(stakeAmount);

        assertEq(staking.balances(alice), 0);
        assertEq(staking.totalStacked(), 0);
        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
    }

    function test_WithdrawMoreThanStaked() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.prank(alice);
        vm.expectRevert();
        staking.withdraw(stakeAmount + 1);
    }

    function test_EarnRewards() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        // Mine some blocks
        vm.roll(block.number + 10);

        uint256 expectedReward = 10 * REWARD_RATE * stakeAmount;
        assertEq(staking.earned(alice), expectedReward);
    }

    function test_GetReward() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        // Mine some blocks
        vm.roll(block.number + 10);

        uint256 expectedReward = 10 * REWARD_RATE * stakeAmount;
        uint256 initialRewardBalance = rewardToken.balanceOf(alice);

        vm.prank(alice);
        staking.getReward();

        assertEq(rewardToken.balanceOf(alice), initialRewardBalance + expectedReward);
        assertEq(staking.earned(alice), 0);
    }

    function test_GetRewardWhenDisabled() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.roll(block.number + 10);

        vm.prank(owner);
        staking.changeEnabled(false);

        vm.prank(alice);
        vm.expectRevert();
        staking.getReward();
    }

    function test_Exit() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        // Mine some blocks
        vm.roll(block.number + 10);

        uint256 expectedReward = 10 * REWARD_RATE * stakeAmount;
        uint256 initialRewardBalance = rewardToken.balanceOf(alice);

        vm.prank(alice);
        staking.exit();

        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
        assertEq(rewardToken.balanceOf(alice), initialRewardBalance + expectedReward);
        assertEq(staking.balances(alice), 0);
        assertEq(staking.earned(alice), 0);
    }

    function test_ExitWhenDisabled() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.roll(block.number + 10);

        vm.prank(owner);
        staking.changeEnabled(false);

        vm.prank(alice);
        staking.exit();

        // Should only withdraw stake, not rewards
        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
        assertEq(staking.balances(alice), 0);
    }

    function test_ChangeRewardRate() public {
        uint256 newRate = 20 wei;
        vm.prank(owner);
        staking.changeRewardRate(newRate);
        assertEq(staking.rewardRate(), newRate);
    }

    function test_ChangeRewardRateNotOwner() public {
        uint256 newRate = 20 wei;
        vm.prank(alice);
        vm.expectRevert();
        staking.changeRewardRate(newRate);
    }
}
