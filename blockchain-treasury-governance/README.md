# Community Treasury Smart Contract

A secure and transparent smart contract for managing community funds through decentralized governance. This contract enables community members to create proposals, vote on fund allocations, and execute approved transactions.

## Features

- **Decentralized Fund Management**: Secure handling of community treasury funds
- **Proposal System**: Create and vote on funding proposals
- **Governance Mechanism**: Democratic decision-making through voting
- **Security Measures**: Built-in checks and deposit requirements
- **Emergency Controls**: Admin-controlled emergency withdrawal function

## Key Parameters

- Voting Duration: 10,000 blocks
- Required Proposal Deposit: 1,000,000 microSTX
- Minimum Votes for Quorum: 500 votes
- Minimum Approval Percentage: 51% (510/1000)

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

4. `process-approved-proposal(proposal-id)`
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

### Admin Functions

1. `update-admin-address(new-admin-address)`
   - Updates the contract administrator
   - Only callable by current admin

2. `emergency-withdrawal()`
   - Allows admin to withdraw all funds in emergency
   - Safety measure for critical situations

## Error Codes

- `ERROR-NOT-AUTHORIZED (u100)`: Unauthorized access attempt
- `ERROR-TREASURY-BALANCE-TOO-LOW (u101)`: Insufficient treasury funds
- `ERROR-INVALID-AMOUNT (u102)`: Invalid transaction amount
- `ERROR-PROPOSAL-NOT-FOUND (u103)`: Proposal ID doesn't exist
- `ERROR-DUPLICATE-VOTE (u104)`: Member already voted
- `ERROR-VOTING-PERIOD-EXPIRED (u105)`: Proposal voting period ended
- `ERROR-INSUFFICIENT-PROPOSAL-DEPOSIT (u106)`: Inadequate proposal deposit
- `ERROR-INVALID-RECIPIENT-ADDRESS (u107)`: Invalid recipient address
- `ERROR-INVALID-PROPOSAL-DESCRIPTION (u108)`: Invalid proposal description
- `ERROR-INVALID-ADMIN-ADDRESS (u109)`: Invalid admin address

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

5. Admin Controls
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