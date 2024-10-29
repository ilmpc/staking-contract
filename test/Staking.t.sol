// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Staking} from "../src/Staking.sol";
import {MockERC20 as ERC20} from "forge-std/mocks/MockERC20.sol";
import {console} from "forge-std/console.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) {
        initialize(name, symbol, decimals);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
}

contract StakingTest is Test {
    Staking public staking;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;

    address public owner;
    address public alice;
    address public bob;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;
    uint256 public constant REWARD_RATE = 10; // 10% APR

    function setUp() public {
        owner = address(this);
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy mock tokens
        stakingToken = new MockERC20("Staking Token", "STK", 18);
        rewardToken = new MockERC20("Reward Token", "RWD", 18);

        // Deploy staking contract
        staking = new Staking(
            address(stakingToken),
            address(rewardToken),
            REWARD_RATE
        );

        // Setup initial token balances
        stakingToken.mint(alice, INITIAL_SUPPLY);
        stakingToken.mint(bob, INITIAL_SUPPLY);
        rewardToken.mint(address(staking), INITIAL_SUPPLY);

        // Approve staking contract
        vm.prank(alice);
        stakingToken.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        stakingToken.approve(address(staking), type(uint256).max);
    }

    function test_Constructor() public view {
        assertEq(staking.owner(), owner);
        assertEq(address(staking.stakingToken()), address(stakingToken));
        assertEq(address(staking.rewardToken()), address(rewardToken));
        assertEq(staking.rewardRate(), (REWARD_RATE * 1 ether) / 365 days);
        assertTrue(staking.enabled());
    }

    function test_Stake() public {
        uint256 stakeAmount = 100 ether;

        vm.prank(alice);
        staking.stake(stakeAmount);

        (
            uint256 lastComputedAt,
            uint256 computedReward,
            uint256 amount
        ) = staking.stakes(alice);
        assertEq(amount, stakeAmount);
        assertEq(lastComputedAt, block.timestamp);
        assertEq(computedReward, 0);
    }

    function test_StakeMultipleTimes() public {
        uint256 firstStake = 100 ether;
        uint256 secondStake = 50 ether;

        vm.startPrank(alice);
        staking.stake(firstStake);

        // Advance time to accumulate rewards
        skip(7 days);

        staking.stake(secondStake);
        vm.stopPrank();

        (, , uint256 totalStaked) = staking.stakes(alice);
        assertEq(totalStaked, firstStake + secondStake);
    }

    function test_Unstake() public {
        uint256 stakeAmount = 100 ether;

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        skip(30 days);

        uint256 unstakeAmount = 50 ether;
        staking.unstake(unstakeAmount);
        vm.stopPrank();

        (, , uint256 remainingStake) = staking.stakes(alice);
        assertEq(remainingStake, stakeAmount - unstakeAmount);
    }

    function test_RewardCalculation() public {
        uint256 stakeAmount = 100 ether;

        vm.prank(alice);
        staking.stake(stakeAmount);
        (uint256 l, uint256 c, uint256 h) = staking.stakes(alice);
        console.logUint(l);
        console.logUint(c);
        console.logUint(h);

        // Advance time by 365 days
        skip(365 days);

        // Expected reward should be 10% of stake amount (REWARD_RATE = 10)
        uint256 expectedReward = (stakeAmount * REWARD_RATE) / 100;
        uint256 actualReward = staking.getTotalUnclaimedReward(alice);

        // Allow for small rounding differences
        assertApproxEqRel(actualReward, expectedReward, 1e16); // 1% tolerance
    }

    function test_ClaimReward() public {
        uint256 stakeAmount = 100 ether;

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        skip(365 days);

        uint256 beforeBalance = rewardToken.balanceOf(alice);
        staking.claimReward();
        uint256 afterBalance = rewardToken.balanceOf(alice);

        assertTrue(afterBalance > beforeBalance);
        vm.stopPrank();
    }

    function test_UnstakeAndClaimReward() public {
        uint256 stakeAmount = 100 ether;

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        skip(365 days);

        uint256 beforeStakingBalance = stakingToken.balanceOf(alice);
        uint256 beforeRewardBalance = rewardToken.balanceOf(alice);

        staking.unstakeAndClaimReward();

        uint256 afterStakingBalance = stakingToken.balanceOf(alice);
        uint256 afterRewardBalance = rewardToken.balanceOf(alice);

        assertEq(afterStakingBalance, beforeStakingBalance + stakeAmount);
        assertTrue(afterRewardBalance > beforeRewardBalance);
        vm.stopPrank();
    }

    function test_RevertWhenDisabled() public {
        uint256 stakeAmount = 100 ether;

        // Disable staking
        staking.setEnabled(false);

        vm.expectRevert();
        vm.prank(alice);
        staking.stake(stakeAmount);
    }

    function test_OnlyOwnerCanChangeSettings() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.setRewardRate(20);

        vm.prank(alice);
        vm.expectRevert();
        staking.setEnabled(false);
    }

    function testFuzz_Stake(uint256 amount) public {
        // Bound the amount to something reasonable
        amount = bound(amount, 1 ether, 1_000_000 ether);

        vm.prank(alice);
        staking.stake(amount);

        (, , uint256 stakedAmount) = staking.stakes(alice);
        assertEq(stakedAmount, amount);
    }

    function testFuzz_StakeAndUnstake(
        uint256 stakeAmount,
        uint256 timeElapsed,
        uint256 unstakeAmount
    ) public {
        // Bound the inputs to reasonable values
        stakeAmount = bound(stakeAmount, 1 ether, 1_000_000 ether);
        timeElapsed = bound(timeElapsed, 1 days, 365 days);

        vm.startPrank(alice);
        staking.stake(stakeAmount);

        skip(timeElapsed);

        unstakeAmount = bound(unstakeAmount, 0, stakeAmount);
        if (unstakeAmount > 0) {
            staking.unstake(unstakeAmount);
        }

        (, , uint256 remainingStake) = staking.stakes(alice);
        assertEq(remainingStake, stakeAmount - unstakeAmount);
        vm.stopPrank();
    }
}
