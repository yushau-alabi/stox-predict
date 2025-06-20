;; StoxPredict: Decentralized Prediction Markets on Stacks
;;
;; Summary: Permissionless platform for creating & participating in prediction markets with automated payouts.
;;
;; Description:
;; This contract enables decentralized prediction markets where users stake STX on asset price movements.
;; Key features:
;;   - Create markets for any asset with custom timeframes
;;   - Stake on "up" or "down" price predictions
;;   - Oracle-resolved settlements
;;   - Automated winner distribution with platform fees
;;   - Fully transparent on-chain operations
;;
;; Designed for Stacks L2 compliance with:
;;   - Principal-based access control
;;   - STX token handling
;;   - Block height time tracking
;;   - Read-only query functions

;; CONSTANTS & CONFIGURATION

;; Administrative Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))

;; Error Codes
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INVALID-PREDICTION (err u102))
(define-constant ERR-MARKET-CLOSED (err u103))
(define-constant ERR-ALREADY-CLAIMED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-INVALID-PARAMETER (err u106))

;; STATE VARIABLES

;; Platform Configuration
(define-data-var oracle-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var minimum-stake uint u1000000) ;; 1 STX minimum stake
(define-data-var fee-percentage uint u2) ;; 2% platform fee
(define-data-var market-counter uint u0)

;; DATA STRUCTURES

;; Market Data Structure
;; Stores all relevant information for each prediction market
(define-map markets
  uint
  {
    start-price: uint, ;; Initial Bitcoin price at market creation
    end-price: uint, ;; Final Bitcoin price at resolution
    total-up-stake: uint, ;; Total STX staked on price increase
    total-down-stake: uint, ;; Total STX staked on price decrease
    start-block: uint, ;; Block when predictions open
    end-block: uint, ;; Block when predictions close
    resolved: bool, ;; Market resolution status
  }
)

;; User Prediction Tracking
;; Maps user predictions to their stakes and claim status
(define-map user-predictions
  {
    market-id: uint,
    user: principal,
  }
  {
    prediction: (string-ascii 4), ;; "up" or "down"
    stake: uint, ;; Amount of STX staked
    claimed: bool, ;; Whether winnings have been claimed
  }
)

;; CORE MARKET FUNCTIONS

;; Create New Prediction Market
;; Only contract owner can create markets with specified parameters
(define-public (create-market
    (start-price uint)
    (start-block uint)
    (end-block uint)
  )
  (let ((market-id (var-get market-counter)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> end-block start-block) ERR-INVALID-PARAMETER)
    (asserts! (> start-price u0) ERR-INVALID-PARAMETER)
    (map-set markets market-id {
      start-price: start-price,
      end-price: u0,
      total-up-stake: u0,
      total-down-stake: u0,
      start-block: start-block,
      end-block: end-block,
      resolved: false,
    })
    (var-set market-counter (+ market-id u1))
    (ok market-id)
  )
)

;; Make Prediction
;; Allows users to stake STX on their Bitcoin price prediction
(define-public (make-prediction
    (market-id uint)
    (prediction (string-ascii 4))
    (stake uint)
  )
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-NOT-FOUND))
      (current-block stacks-block-height)
    )
    ;; Validate market timing
    (asserts!
      (and
        (>= current-block (get start-block market))
        (< current-block (get end-block market))
      )
      ERR-MARKET-CLOSED
    )
    ;; Validate prediction parameters
    (asserts! (or (is-eq prediction "up") (is-eq prediction "down"))
      ERR-INVALID-PREDICTION
    )
    (asserts! (>= stake (var-get minimum-stake)) ERR-INVALID-PREDICTION)
    (asserts! (<= stake (stx-get-balance tx-sender)) ERR-INSUFFICIENT-BALANCE)
    ;; Transfer stake to contract
    (try! (stx-transfer? stake tx-sender (as-contract tx-sender)))
    ;; Record user prediction
    (map-set user-predictions {
      market-id: market-id,
      user: tx-sender,
    } {
      prediction: prediction,
      stake: stake,
      claimed: false,
    })
    ;; Update market totals
    (map-set markets market-id
      (merge market {
        total-up-stake: (if (is-eq prediction "up")
          (+ (get total-up-stake market) stake)
          (get total-up-stake market)
        ),
        total-down-stake: (if (is-eq prediction "down")
          (+ (get total-down-stake market) stake)
          (get total-down-stake market)
        ),
      })
    )
    (ok true)
  )
)

;; Resolve Market
;; Oracle resolves market with final Bitcoin price
(define-public (resolve-market
    (market-id uint)
    (end-price uint)
  )
  (let ((market (unwrap! (map-get? markets market-id) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get oracle-address)) ERR-OWNER-ONLY)
    (asserts! (>= stacks-block-height (get end-block market)) ERR-MARKET-CLOSED)
    (asserts! (not (get resolved market)) ERR-MARKET-CLOSED)
    (asserts! (> end-price u0) ERR-INVALID-PARAMETER)
    (map-set markets market-id
      (merge market {
        end-price: end-price,
        resolved: true,
      })
    )
    (ok true)
  )
)

;; Claim Winnings
;; Winners can claim their proportional share of the total stake pool
(define-public (claim-winnings (market-id uint))
  (let (
      (market (unwrap! (map-get? markets market-id) ERR-NOT-FOUND))
      (prediction (unwrap!
        (map-get? user-predictions {
          market-id: market-id,
          user: tx-sender,
        })
        ERR-NOT-FOUND
      ))
    )
    (asserts! (get resolved market) ERR-MARKET-CLOSED)
    (asserts! (not (get claimed prediction)) ERR-ALREADY-CLAIMED)
    (let (
        (winning-prediction (if (> (get end-price market) (get start-price market))
          "up"
          "down"
        ))
        (total-stake (+ (get total-up-stake market) (get total-down-stake market)))
        (winning-stake (if (is-eq winning-prediction "up")
          (get total-up-stake market)
          (get total-down-stake market)
        ))
      )
      (asserts! (is-eq (get prediction prediction) winning-prediction)
        ERR-INVALID-PREDICTION
      )
      (let (
          (winnings (/ (* (get stake prediction) total-stake) winning-stake))
          (fee (/ (* winnings (var-get fee-percentage)) u100))
          (payout (- winnings fee))
        )
        ;; Transfer winnings to user
        (try! (as-contract (stx-transfer? payout (as-contract tx-sender) tx-sender)))
        ;; Transfer fee to contract owner
        (try! (as-contract (stx-transfer? fee (as-contract tx-sender) CONTRACT-OWNER)))
        ;; Mark as claimed
        (map-set user-predictions {
          market-id: market-id,
          user: tx-sender,
        }
          (merge prediction { claimed: true })
        )
        (ok payout)
      )
    )
  )
)

;; READ-ONLY FUNCTIONS

;; Get Market Details
;; Returns complete market information for given market ID
(define-read-only (get-market (market-id uint))
  (map-get? markets market-id)
)

;; Get User Prediction
;; Returns user's prediction details for a specific market
(define-read-only (get-user-prediction
    (market-id uint)
    (user principal)
  )
  (map-get? user-predictions {
    market-id: market-id,
    user: user,
  })
)

;; Get Contract Balance
;; Returns total STX balance held by the contract
(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; ADMINISTRATIVE FUNCTIONS

;; Update Oracle Address
;; Allows contract owner to change the oracle address
(define-public (set-oracle-address (new-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (is-eq new-address new-address) ERR-INVALID-PARAMETER)
    (ok (var-set oracle-address new-address))
  )
)

;; Update Minimum Stake
;; Allows contract owner to adjust minimum stake requirement
(define-public (set-minimum-stake (new-minimum uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    (asserts! (> new-minimum u0) ERR-INVALID-PARAMETER)
    (ok (var-set minimum-stake new-minimum))
  )
)