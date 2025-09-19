;; Payment Streaming Smart Contract
;; A robust contract for streaming payments with comprehensive features

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_STREAM_NOT_FOUND (err u102))
(define-constant ERR_STREAM_ALREADY_EXISTS (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))
(define-constant ERR_STREAM_ENDED (err u105))
(define-constant ERR_INVALID_DURATION (err u106))
(define-constant ERR_STREAM_NOT_ACTIVE (err u107))
(define-constant ERR_ALREADY_WITHDRAWN (err u108))

;; Data Variables
(define-data-var next-stream-id uint u1)
(define-data-var platform-fee-rate uint u25) ;; 0.25% in basis points

;; Data Maps
(define-map streams
  uint
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    start-time: uint,
    end-time: uint,
    withdrawn: uint,
    is-active: bool,
    rate-per-second: uint
  }
)

(define-map user-stream-count principal uint)
(define-map stream-withdrawals uint uint)

;; Private Functions
(define-private (calculate-withdrawable-amount (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) u0))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (stream-start (get start-time stream-data))
    (stream-end (get end-time stream-data))
    (rate (get rate-per-second stream-data))
    (already-withdrawn (get withdrawn stream-data))
  )
    (if (>= current-time stream-end)
      (- (get amount stream-data) already-withdrawn)
      (if (>= current-time stream-start)
        (- (* rate (- current-time stream-start)) already-withdrawn)
        u0
      )
    )
  )
)

(define-private (is-stream-owner (stream-id uint) (user principal))
  (match (map-get? streams stream-id)
    stream-data (or (is-eq (get sender stream-data) user)
                   (is-eq (get recipient stream-data) user))
    false
  )
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-rate)) u10000)
)

;; Public Functions

;; Create a new payment stream
(define-public (create-stream (recipient principal) (amount uint) (duration uint))
  (let (
    (stream-id (var-get next-stream-id))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (end-time (+ current-time duration))
    (rate-per-second (/ amount duration))
    (platform-fee (calculate-platform-fee amount))
    (total-cost (+ amount platform-fee))
  )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (> duration u0) ERR_INVALID_DURATION)
    (asserts! (not (is-eq tx-sender recipient)) ERR_NOT_AUTHORIZED)
    (asserts! (>= (stx-get-balance tx-sender) total-cost) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
    
    ;; Store stream data
    (map-set streams stream-id {
      sender: tx-sender,
      recipient: recipient,
      amount: amount,
      start-time: current-time,
      end-time: end-time,
      withdrawn: u0,
      is-active: true,
      rate-per-second: rate-per-second
    })
    
    ;; Update counters
    (var-set next-stream-id (+ stream-id u1))
    (map-set user-stream-count tx-sender 
      (+ (default-to u0 (map-get? user-stream-count tx-sender)) u1))
    
    (ok stream-id)
  )
)

;; Withdraw available funds from a stream
(define-public (withdraw-from-stream (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
    (withdrawable (calculate-withdrawable-amount stream-id))
  )
    (asserts! (is-eq tx-sender (get recipient stream-data)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active stream-data) ERR_STREAM_NOT_ACTIVE)
    (asserts! (> withdrawable u0) ERR_ALREADY_WITHDRAWN)
    
    ;; Update withdrawn amount
    (map-set streams stream-id
      (merge stream-data { withdrawn: (+ (get withdrawn stream-data) withdrawable) }))
    
    ;; Transfer STX to recipient
    (try! (as-contract (stx-transfer? withdrawable tx-sender (get recipient stream-data))))
    
    (ok withdrawable)
  )
)

;; Cancel an active stream (only sender can cancel)
(define-public (cancel-stream (stream-id uint))
  (let (
    (stream-data (unwrap! (map-get? streams stream-id) ERR_STREAM_NOT_FOUND))
    (withdrawable (calculate-withdrawable-amount stream-id))
    (remaining (- (get amount stream-data) (get withdrawn stream-data) withdrawable))
  )
    (asserts! (is-eq tx-sender (get sender stream-data)) ERR_NOT_AUTHORIZED)
    (asserts! (get is-active stream-data) ERR_STREAM_NOT_ACTIVE)
    
    ;; Mark stream as inactive
    (map-set streams stream-id (merge stream-data { is-active: false }))
    
    ;; Transfer withdrawable amount to recipient if any
    (if (> withdrawable u0)
      (try! (as-contract (stx-transfer? withdrawable tx-sender (get recipient stream-data))))
      true
    )
    
    ;; Refund remaining amount to sender
    (if (> remaining u0)
      (try! (as-contract (stx-transfer? remaining tx-sender (get sender stream-data))))
      true
    )
    
    (ok true)
  )
)

;; Update platform fee (only contract owner)
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (<= new-fee u1000) ERR_INVALID_AMOUNT) ;; Max 10%
    (var-set platform-fee-rate new-fee)
    (ok true)
  )
)

;; Batch withdraw from multiple streams
(define-public (batch-withdraw (stream-ids (list 10 uint)))
  (let (
    (results (map withdraw-single-stream stream-ids))
  )
    (ok results)
  )
)

(define-private (withdraw-single-stream (stream-id uint))
  (match (withdraw-from-stream stream-id)
    success success
    error u0
  )
)

;; Read-only Functions

;; Get stream details
(define-read-only (get-stream (stream-id uint))
  (map-get? streams stream-id)
)

;; Get withdrawable amount for a stream
(define-read-only (get-withdrawable-amount (stream-id uint))
  (calculate-withdrawable-amount stream-id)
)

;; Get user's stream count
(define-read-only (get-user-stream-count (user principal))
  (default-to u0 (map-get? user-stream-count user))
)

;; Get current platform fee rate
(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

;; Check if stream is active
(define-read-only (is-stream-active (stream-id uint))
  (match (map-get? streams stream-id)
    stream-data (get is-active stream-data)
    false
  )
)

;; Get stream progress (percentage completed)
(define-read-only (get-stream-progress (stream-id uint))
  (match (map-get? streams stream-id)
    stream-data 
      (let (
        (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
        (start-time (get start-time stream-data))
        (end-time (get end-time stream-data))
        (duration (- end-time start-time))
        (elapsed (if (> current-time end-time) 
                   duration 
                   (if (< current-time start-time) u0 (- current-time start-time))))
      )
        (if (is-eq duration u0) u0 (/ (* elapsed u100) duration))
      )
    u0
  )
)

;; Get next available stream ID
(define-read-only (get-next-stream-id)
  (var-get next-stream-id)
)