# Staking

1. Contract State Variables:

   - Mapping of staker addresses to staked amounts
   - Reward token address (ERC20)
   - Staking token address (ERC20)
   - Reward rate per block/second
   - Timestamp of last reward calculation
   - Accumulated rewards per token
   - User reward debt tracking

2. Core Functions:

   - stake(uint amount): Lock tokens in contract
   - withdraw(uint amount): Remove staked tokens
   - getReward(): Claim accumulated rewards
   - exit(): Withdraw all + claim rewards

3. Reward Calculation:

   - Track time elapsed since last update
   - Calculate rewards based on: stake amount × time × rate
   - Update reward debt when user stakes/withdraws
   - Store earned but unclaimed rewards per user

4. Admin Functions:

   - Set reward rate
   - Fund contract with reward tokens
   - Emergency withdrawal (safety)
   - Pause/unpause functionality

5. View Functions:
   - earned(address): Show pending rewards
   - totalStaked(): Total tokens locked
   - userStakeInfo(address): User's stake details
