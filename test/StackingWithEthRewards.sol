// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {StackingWithEthRewards} from "../src/StackingWithEthRewards.sol";
import {MockERC20 as ERC20} from "forge-std/mocks/MockERC20.sol";

contract MockERC20 is ERC20 {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// Malicious contract to demonstrate reentrancy
contract ReentrancyAttacker {
    StackingWithEthRewards public staking;
    MockERC20 public stakingToken;
    uint256 public attackCount;
    uint256 public maxAttacks;

    constructor(address _staking, address _stakingToken) {
        staking = StackingWithEthRewards(_staking);
        stakingToken = MockERC20(_stakingToken);
    }

    function setup(uint256 amount) external {
        stakingToken.approve(address(staking), type(uint256).max);
        staking.stake(amount);
    }

    function attack(uint256 _maxAttacks) external {
        maxAttacks = _maxAttacks;
        attackCount = 0;
        staking.getReward();
    }

    receive() external payable {
        if (attackCount < maxAttacks) {
            attackCount++;
            staking.getReward();
        }
    }
}

contract StackingWithEthRewardsTest is Test {
    StackingWithEthRewards public staking;
    MockERC20 public stakingToken;
    address public alice;
    address public bob;
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant REWARD_RATE = 10 wei;

    function setUp() public {
        // Setup accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Deploy mock token
        stakingToken = new MockERC20();
        stakingToken.initialize("Staking Token", "STK", 18);

        // Deploy staking contract
        staking = new StackingWithEthRewards(
            address(stakingToken),
            REWARD_RATE
        );

        // Fund staking contract with ETH for rewards
        vm.deal(address(staking), 1000000000 ether);

        // Setup initial balances
        stakingToken.mint(alice, INITIAL_BALANCE);
        stakingToken.mint(bob, INITIAL_BALANCE);
        stakingToken.mint(address(this), INITIAL_BALANCE);

        // Approve staking contract
        vm.prank(alice);
        stakingToken.approve(address(staking), type(uint256).max);
        vm.prank(bob);
        stakingToken.approve(address(staking), type(uint256).max);
    }

    function test_InitialState() public view {
        assertEq(address(staking.stackingToken()), address(stakingToken));
        assertEq(staking.rewardRate(), REWARD_RATE);
    }

    function test_Stake() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        assertEq(staking.balances(alice), stakeAmount);
        assertEq(stakingToken.balanceOf(address(staking)), stakeAmount);
    }

    function test_Withdraw() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.prank(alice);
        staking.withdraw(stakeAmount);

        assertEq(staking.balances(alice), 0);
        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
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
        uint256 initialBalance = alice.balance;

        vm.prank(alice);
        staking.getReward();

        assertEq(alice.balance, initialBalance + expectedReward);
        assertEq(staking.earned(alice), 0);
    }

    function test_Exit() public {
        uint256 stakeAmount = 100 ether;
        vm.prank(alice);
        staking.stake(stakeAmount);

        // Mine some blocks
        vm.roll(block.number + 10);

        uint256 expectedReward = 10 * REWARD_RATE * stakeAmount;
        uint256 initialEthBalance = alice.balance;

        vm.prank(alice);
        staking.exit();

        assertEq(stakingToken.balanceOf(alice), INITIAL_BALANCE);
        assertEq(alice.balance, initialEthBalance + expectedReward);
        assertEq(staking.balances(alice), 0);
        assertEq(staking.earned(alice), 0);
    }

    function testFail_ReentrancyAttack() public {
        // Deploy attacker contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(
            address(staking),
            address(stakingToken)
        );

        // Fund attacker with tokens
        stakingToken.transfer(address(attacker), 100 ether);

        // Setup initial stake
        attacker.setup(100 ether);

        // Mine some blocks to accumulate rewards
        vm.roll(block.number + 10);

        // Record initial balances
        uint256 initialContractEth = address(staking).balance;
        uint256 initialAttackerEth = address(attacker).balance;

        // Launch attack
        attacker.attack(3);

        // Verify the attack was successful
        assertTrue(
            address(attacker).balance > initialAttackerEth,
            "Attacker balance should have increased"
        );
        assertTrue(
            address(staking).balance < initialContractEth,
            "Contract balance should have decreased"
        );
        assertTrue(
            attacker.attackCount() > 1,
            "Multiple reward claims should have succeeded"
        );
    }
}
