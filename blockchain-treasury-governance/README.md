# Community Treasury Smart Contract

A secure and transparent smart contract for managing community funds through decentralized governance. This contract enables community members to create proposals, vote on fund allocations, and execute approved transactions.

## Features

- **Decentralized Fund Management**: Secure handling of community treasury funds
- **Proposal System**: Create and vote on funding proposals
- **Governance Mechanism**: Democratic decision-making through voting
- **Security Measures**: Built-in checks and deposit requirements
- **Emergency Controls**: Admin-controlled emergency withdrawal function

## Key Parameters

- Voting Duration: 10,000 blocks (`VOTING_DURATION_BLOCKS`)
- Required Proposal Deposit: 1,000,000 microSTX (`REQUIRED_PROPOSAL_DEPOSIT`)
- Minimum Votes for Quorum: 500 votes (`MINIMUM_VOTES_FOR_QUORUM`)
- Minimum Approval Percentage: 51% (510/1000) (`MINIMUM_APPROVAL_PERCENTAGE`)
- Proposal Cooldown: 1,000 blocks (`PROPOSAL_COOLDOWN_BLOCKS`)
- Minimum Proposal Amount: 100,000 microSTX (`MINIMUM_PROPOSAL_AMOUNT`)
- Timelock Period: 144 blocks (~24 hours) (`TIMELOCK_PERIOD_BLOCKS`)

## Functions

### User Functions

1. `deposit-funds()`
   - Allows members to deposit STX into the treasury
   - Automatically tracks individual member deposits

2. `create-proposal(withdrawal-amount, recipient-address, proposal-text)`
   - Creates a new funding proposal
   - Requires proposal deposit
   - Parameters:
     - `withdrawal-amount`: Amount of STX to withdraw
     - `recipient-address`: Beneficiary address
     - `proposal-text`: Description (max 256 characters)

3. `vote-on-proposal(proposal-id, vote-in-favor)`
   - Casts a vote on an active proposal
   - One vote per member per proposal
   - Must vote within voting period

4. `cancel-proposal(proposal-id)`
   - Allows proposal creator to cancel an active proposal
   - Returns deposit to the creator

5. `process-approved-proposal(proposal-id)`
   - Executes approved proposals
   - Transfers funds to recipient
   - Returns proposal deposit to creator

### Read-Only Functions

1. `get-treasury-balance()`
   - Returns current treasury balance

2. `get-proposal-info(proposal-id)`
   - Returns detailed proposal information

3. `has-member-voted(proposal-id, voter-address)`
   - Checks if a member has voted on a specific proposal

4. `get-member-deposit-amount(member-address)`
   - Returns total deposits made by a member

5. `check-proposal-quorum(proposal-id)`
   - Checks if a proposal has reached quorum

6. `is-proposal-executable(proposal-id)`
   - Checks if a proposal can be executed

### Admin Functions

1. `update-admin-address(new-admin-address)`
   - Updates the contract administrator
   - Only callable by current admin

2. `emergency-withdrawal()`
   - Allows admin to withdraw all funds in emergency
   - Safety measure for critical situations

## Error Codes

- `ERR_NOT_AUTHORIZED (u100)`: Unauthorized access attempt
- `ERR_TREASURY_BALANCE_TOO_LOW (u101)`: Insufficient treasury funds
- `ERR_INVALID_AMOUNT (u102)`: Invalid transaction amount
- `ERR_PROPOSAL_NOT_FOUND (u103)`: Proposal ID doesn't exist
- `ERR_DUPLICATE_VOTE (u104)`: Member already voted
- `ERR_VOTING_PERIOD_EXPIRED (u105)`: Proposal voting period ended
- `ERR_INSUFFICIENT_PROPOSAL_DEPOSIT (u106)`: Inadequate proposal deposit
- `ERR_INVALID_RECIPIENT_ADDRESS (u107)`: Invalid recipient address
- `ERR_INVALID_PROPOSAL_DESCRIPTION (u108)`: Invalid proposal description
- `ERR_INVALID_ADMIN_ADDRESS (u109)`: Invalid admin address
- `ERR_PROPOSAL_IN_COOLDOWN (u110)`: Cannot create proposal during cooldown period
- `ERR_PROPOSAL_IN_TIMELOCK (u111)`: Proposal is in timelock period
- `ERR_BELOW_MINIMUM_PROPOSAL_AMOUNT (u112)`: Proposal amount below minimum
- `ERR_CANNOT_CANCEL (u113)`: Cannot cancel proposal

## Security Features

1. Proposal Deposit Requirement
   - Prevents spam proposals
   - Returned upon proposal completion

2. Voting Period Limitations
   - Fixed duration for voting
   - Prevents late voting

3. Quorum Requirements
   - Minimum vote threshold
   - Minimum approval percentage

4. Address Validation
   - Prevents self-dealing
   - Validates recipient addresses

5. Timelock Period
   - 24-hour waiting period after approval before execution
   - Provides time for community to react to approved proposals

6. Proposal Cooldown
   - Limits frequency of proposal creation
   - Prevents flooding the system

7. Admin Controls
   - Emergency withdrawal capability
   - Admin address management

## Usage Example

```clarity
;; Create a new proposal
(contract-call? .treasury create-proposal 
    u1000000 ;; withdrawal amount
    'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; recipient
    "Community event funding") ;; description

;; Vote on the proposal
(contract-call? .treasury vote-on-proposal u1 true)

;; Process approved proposal
(contract-call? .treasury process-approved-proposal u1)
```

## Best Practices

1. Always verify proposal details before voting
2. Check treasury balance before creating proposals
3. Ensure proposal descriptions are clear and concise
4. Monitor voting periods for timely participation
5. Verify recipient addresses carefully

## Recent Updates

- **Code Style Improvements**: Updated constant naming to follow Clarity convention
  - Changed all constant names to use `SCREAMING_SNAKE_CASE` instead of kebab-case
  - Renamed error constants from `ERROR-*` to `ERR_*` to follow Clarity naming best practices
  - Updated all references to constants throughout the contract