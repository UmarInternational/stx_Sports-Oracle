# StackSports Oracle 

A decentralized sports prediction platform built on Stacks blockchain, enabling users to make predictions on sports events and earn rewards based on accuracy.

## Features

- **Sports Event Management**: Create and manage sports events with team matchups
- **Oracle System**: Decentralized result verification by staked validators
- **Prediction Markets**: Stake STX on game outcomes with confidence levels
- **Reward System**: Earn 2x rewards for correct predictions
- **User Statistics**: Track prediction accuracy and earnings
- **Emergency Controls**: Admin pause functionality for security

## Quick Start

### Prerequisites
- Stacks wallet (Hiro Wallet recommended)
- STX tokens for staking

### Contract Functions

#### User Actions
- `submit-prediction(event-id, predicted-winner, stake-amount, confidence-level)` - Make predictions
- `claim-prediction-reward(event-id)` - Claim winnings from correct predictions

#### Oracle Functions  
- `register-oracle-validator(stake-amount)` - Become a result validator (min 10 STX)
- `submit-oracle-result(event-id, home-score, away-score)` - Submit game results

#### Admin Functions
- `create-sports-event(home-team, away-team, sport, start-time)` - Create new events
- `toggle-emergency-pause()` - Pause/unpause contract

### Read-Only Functions
- `get-sports-event(event-id)` - Get event details
- `get-user-prediction(user, event-id)` - Get prediction info
- `get-user-stats(user)` - Get user statistics
- `calculate-accuracy(user)` - Calculate prediction accuracy percentage

## Constants

- Minimum stake: 1 STX
- Platform fee: 5%
- Oracle validator minimum: 10 STX
- Reward multiplier: 2x for correct predictions

## Contract Architecture

The contract uses several maps to store:
- Sports events and their details
- Oracle validators and their stakes
- User predictions and outcomes
- Event prediction pools
- User statistics and reputation

## Security Features

- Emergency pause mechanism
- Owner-only administrative functions
- Validator staking requirements
- Deadline enforcement for predictions
- Result verification system

## Deployment

Deploy the contract to Stacks testnet/mainnet using Clarinet or Stacks CLI.

```bash
clarinet deploy --network testnet
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes with Clarinet
4. Submit a pull request

## License

MIT License - see LICENSE file for details.