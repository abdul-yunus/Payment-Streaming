# Payment Streaming Smart Contract

A robust Clarity smart contract that enables continuous payment streaming on the Stacks blockchain. This contract allows users to create payment streams that release funds gradually over time, perfect for subscriptions, salaries, or any time-based payment scenarios.

## Features

### Core Functionality
- **Stream Creation**: Create payment streams with customizable duration and amount
- **Gradual Withdrawals**: Recipients can withdraw available funds as they accumulate over time
- **Stream Cancellation**: Stream creators can cancel active streams and receive refunds
- **Platform Fee System**: Configurable fee structure for contract monetization

### Advanced Features
- **Batch Operations**: Withdraw from multiple streams in a single transaction
- **Real-time Progress Tracking**: Monitor stream completion percentage
- **User Analytics**: Track stream statistics per user
- **Automatic Rate Calculation**: Per-second streaming rates calculated automatically

## Contract Overview

### Data Structures
- **Streams**: Core stream data including sender, recipient, amounts, and timing
- **User Statistics**: Track stream counts per user
- **Platform Settings**: Configurable fee rates and system parameters

### Security Features
- Comprehensive error handling with 8 distinct error types
- Access control for all critical operations
- Balance verification before stream creation
- State validation to prevent invalid operations

## Public Functions

### `create-stream`
```clarity
(create-stream (recipient principal) (amount uint) (duration uint))
```
Creates a new payment stream. Requires sufficient STX balance including platform fees.

**Parameters:**
- `recipient`: The principal who will receive the streamed payments
- `amount`: Total STX amount to be streamed (in microSTX)
- `duration`: Stream duration in seconds

**Returns:** Stream ID on success

### `withdraw-from-stream`
```clarity
(withdraw-from-stream (stream-id uint))
```
Withdraws available funds from a stream. Only callable by the stream recipient.

**Parameters:**
- `stream-id`: The ID of the stream to withdraw from

**Returns:** Amount withdrawn on success

### `cancel-stream`
```clarity
(cancel-stream (stream-id uint))
```
Cancels an active stream. Only callable by the stream creator. Transfers available funds to recipient and refunds remaining balance to sender.

**Parameters:**
- `stream-id`: The ID of the stream to cancel

### `batch-withdraw`
```clarity
(batch-withdraw (stream-ids (list 10 uint)))
```
Withdraws from multiple streams in a single transaction (max 10 streams).

**Parameters:**
- `stream-ids`: List of stream IDs to withdraw from

## Read-Only Functions

### `get-stream`
Returns complete stream information including all metadata and current state.

### `get-withdrawable-amount`
Calculates the current withdrawable amount for a stream based on elapsed time.

### `get-stream-progress`
Returns the completion percentage of a stream (0-100).

### `get-user-stream-count`
Returns the total number of streams created by a user.

### `is-stream-active`
Checks if a stream is currently active and accepting operations.

## Usage Examples

### Creating a Stream
```clarity
;; Create a 30-day stream of 1000 STX
(contract-call? .payment-streaming create-stream 'SP1ABC...XYZ u1000000000 u2592000)
```

### Withdrawing from a Stream
```clarity
;; Withdraw available funds from stream #1
(contract-call? .payment-streaming withdraw-from-stream u1)
```

### Checking Stream Status
```clarity
;; Get stream details
(contract-call? .payment-streaming get-stream u1)

;; Check withdrawable amount
(contract-call? .payment-streaming get-withdrawable-amount u1)

;; Get completion percentage
(contract-call? .payment-streaming get-stream-progress u1)
```

## Platform Fees

The contract implements a platform fee system:
- Default fee: 0.25% (25 basis points)
- Maximum fee: 10%
- Only contract owner can update fee rates
- Fees are collected during stream creation

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Invalid amount |
| u102 | Stream not found |
| u103 | Stream already exists |
| u104 | Insufficient balance |
| u105 | Stream ended |
| u106 | Invalid duration |
| u107 | Stream not active |
| u108 | Already withdrawn |

## Gas Optimization

The contract is optimized for gas efficiency through:
- O(1) lookups using maps
- Minimal storage operations
- Batch processing capabilities
- Single-transaction fee calculations

## Security Considerations

- All monetary operations include overflow protection
- Access controls prevent unauthorized actions
- State validation ensures data integrity
- Comprehensive error handling prevents edge cases

