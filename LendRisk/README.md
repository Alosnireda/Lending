# DeFi Lending Protocol Smart Contract

This smart contract implements a DeFi lending protocol on the Stacks blockchain using Clarity. The protocol enables users to borrow assets by providing STX as collateral, with upgradeable risk parameters that can adapt to market conditions.

## Key Features
- Collateralized lending mechanism
- Dynamic interest rate model
- Liquidation system for undercollateralized positions
- Upgradeable risk parameters
- Oracle price feed integration
- Emergency pause functionality
- Governance controls for protocol parameters

## Contract Constants
```
LIQUIDATION_THRESHOLD: 150 (represents 150% collateral ratio)
MINIMUM_COLLATERAL_RATIO: 130 (represents 130% minimum ratio)
GRACE_PERIOD: 144 blocks (approximately 24 hours)
```

## Main Functions

### For Borrowers

1. `create-loan (collateral-amount uint) (loan-amount uint)`
   - Creates a new loan with STX collateral
   - Parameters:
     - `collateral-amount`: Amount of STX to deposit as collateral
     - `loan-amount`: Amount of tokens to borrow
   - Returns: Loan ID if successful
   - Requirements:
     - Protocol must not be paused
     - Collateral ratio must meet minimum requirements
     - Valid loan amount

2. `repay-loan (loan-id uint) (repayment-amount uint)`
   - Repays an active loan and releases collateral
   - Parameters:
     - `loan-id`: ID of the loan to repay
     - `repayment-amount`: Amount to repay (including interest)
   - Requirements:
     - Must be the original borrower
     - Loan must be active
     - Repayment amount must cover principal plus interest

### For Liquidators

1. `liquidate-loan (loan-id uint)`
   - Liquidates an undercollateralized loan
   - Parameters:
     - `loan-id`: ID of the loan to liquidate
   - Requirements:
     - Protocol must not be paused
     - Loan must be active
     - Current collateral ratio must be below liquidation threshold

### For Governance

1. `set-protocol-param (param-name (string-ascii 30)) (value uint)`
   - Updates protocol parameters
   - Restricted to contract owner
   - Parameters:
     - `param-name`: Name of the parameter to update
     - `value`: New value for the parameter

2. `toggle-protocol-pause`
   - Toggles the protocol's pause state
   - Restricted to contract owner

3. `update-oracle-price (new-price uint)`
   - Updates the price oracle
   - Restricted to contract owner

### Read-Only Functions

1. `get-loan-details (loan-id uint)`
   - Returns detailed information about a specific loan

2. `get-current-price`
   - Returns the current oracle price

3. `is-liquidatable (loan-id uint)`
   - Checks if a loan can be liquidated

## Data Structures

### Loan Data
```clarity
{
    borrower: principal,
    collateral-amount: uint,
    loan-amount: uint,
    interest-rate: uint,
    start-block: uint,
    last-update: uint,
    status: (string-ascii 20),
    collateral-ratio: uint
}
```

## Error Codes
- `ERR_NOT_AUTHORIZED (u100)`: Unauthorized access
- `ERR_INVALID_AMOUNT (u101)`: Invalid amount specified
- `ERR_INSUFFICIENT_COLLATERAL (u102)`: Collateral below required ratio
- `ERR_LOAN_NOT_FOUND (u103)`: Loan ID doesn't exist
- `ERR_ALREADY_LIQUIDATED (u104)`: Loan is no longer active

## Usage Examples

### Creating a Loan
```clarity
;; Deposit 1000 STX as collateral to borrow 500 tokens
(contract-call? .defi-lending-protocol create-loan u1000 u500)
```

### Repaying a Loan
```clarity
;; Repay loan #1 with amount covering principal plus interest
(contract-call? .defi-lending-protocol repay-loan u1 u550)
```

### Liquidating an Undercollateralized Position
```clarity
;; Liquidate loan #1 if it's below threshold
(contract-call? .defi-lending-protocol liquidate-loan u1)
```

## Security Considerations

1. **Collateral Management**
   - Always maintain required collateral ratio
   - Monitor oracle price updates
   - Be aware of liquidation thresholds

2. **Risk Parameters**
   - Interest rates adjust based on market conditions
   - Liquidation parameters may change
   - Grace periods apply for collateral ratio maintenance

3. **Emergency Procedures**
   - Contract can be paused by governance
   - Oracle prices can be updated for market accuracy
   - Parameters can be adjusted for risk management

## Testing Guidelines

1. Test loan creation with various collateral ratios
2. Verify interest calculation accuracy
3. Test liquidation mechanisms
4. Validate parameter updates
5. Check oracle price impact on collateral ratios

## Development and Deployment

### Prerequisites
- Clarity CLI tools
- Stacks wallet for contract deployment
- Test STX tokens for development

### Deployment Steps
1. Deploy contract to desired network
2. Initialize protocol parameters
3. Set initial oracle price
4. Verify contract functionality

## Monitoring and Maintenance

1. **Regular Monitoring**
   - Track collateral ratios
   - Monitor liquidation events
   - Review interest rate adjustments

2. **Parameter Updates**
   - Adjust risk parameters based on market conditions
   - Update oracle prices regularly
   - Monitor protocol health metrics