;; DeFi Lending Protocol with Upgradeable Risk Parameters
;; Version: 1.0

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_INSUFFICIENT_COLLATERAL (err u102))
(define-constant ERR_LOAN_NOT_FOUND (err u103))
(define-constant ERR_ALREADY_LIQUIDATED (err u104))
(define-constant LIQUIDATION_THRESHOLD u150) ;; 150% collateral ratio
(define-constant MINIMUM_COLLATERAL_RATIO u130) ;; 130% minimum ratio
(define-constant GRACE_PERIOD u144) ;; ~24 hours in blocks

;; Data Maps and Variables
(define-map loans
    { loan-id: uint }
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
)

(define-map user-loans
    { user: principal }
    { active-loans: (list 10 uint) }
)

(define-map protocol-params
    { param-name: (string-ascii 30) }
    { value: uint }
)

(define-data-var next-loan-id uint u1)
(define-data-var protocol-paused bool false)
(define-data-var oracle-price uint u0)

;; Governance Functions
(define-public (set-protocol-param (param-name (string-ascii 30)) (value uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (map-set protocol-params { param-name: param-name } { value: value }))
    )
)

(define-public (toggle-protocol-pause)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (var-set protocol-paused (not (var-get protocol-paused))))
    )
)

(define-public (update-oracle-price (new-price uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (ok (var-set oracle-price new-price))
    )
)

;; Core Lending Functions
(define-public (create-loan (collateral-amount uint) (loan-amount uint))
    (let 
        (
            (loan-id (var-get next-loan-id))
            (current-price (var-get oracle-price))
            (collateral-value (* collateral-amount current-price))
            (collateral-ratio (/ (* collateral-value u100) loan-amount))
            (interest-rate (get-current-interest-rate))
        )
        (asserts! (not (var-get protocol-paused)) ERR_NOT_AUTHORIZED)
        (asserts! (>= collateral-ratio MINIMUM_COLLATERAL_RATIO) ERR_INSUFFICIENT_COLLATERAL)
        (asserts! (> loan-amount u0) ERR_INVALID_AMOUNT)
        
        (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
        
        (map-set loans 
            { loan-id: loan-id }
            {
                borrower: tx-sender,
                collateral-amount: collateral-amount,
                loan-amount: loan-amount,
                interest-rate: interest-rate,
                start-block: block-height,
                last-update: block-height,
                status: "active",
                collateral-ratio: collateral-ratio
            }
        )
        
        (var-set next-loan-id (+ loan-id u1))
        (ok loan-id)
    )
)

(define-public (repay-loan (loan-id uint) (repayment-amount uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND))
            (interest-due (calculate-interest loan-id))
            (total-due (+ (get loan-amount loan) interest-due))
        )
        (asserts! (is-eq (get borrower loan) tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status loan) "active") ERR_ALREADY_LIQUIDATED)
        (asserts! (>= repayment-amount total-due) ERR_INVALID_AMOUNT)
        
        ;; Process repayment and return collateral
        (try! (stx-transfer? (get collateral-amount loan) (as-contract tx-sender) tx-sender))
        
        (map-set loans 
            { loan-id: loan-id }
            (merge loan { status: "repaid" })
        )
        (ok true)
    )
)

(define-public (liquidate-loan (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR_LOAN_NOT_FOUND))
            (current-ratio (get-current-collateral-ratio loan-id))
        )
        (asserts! (not (var-get protocol-paused)) ERR_NOT_AUTHORIZED)
        (asserts! (is-eq (get status loan) "active") ERR_ALREADY_LIQUIDATED)
        (asserts! (< current-ratio LIQUIDATION_THRESHOLD) ERR_INVALID_AMOUNT)
        
        ;; Transfer collateral to liquidator
        (try! (stx-transfer? (get collateral-amount loan) (as-contract tx-sender) tx-sender))
        
        (map-set loans 
            { loan-id: loan-id }
            (merge loan { status: "liquidated" })
        )
        (ok true)
    )
)

;; Helper Functions
(define-private (get-current-interest-rate)
    (default-to u500 (get value (map-get? protocol-params { param-name: "base-interest-rate" })))
)

(define-private (calculate-interest (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) u0))
            (blocks-elapsed (- block-height (get last-update loan)))
            (interest-rate (get interest-rate loan))
        )
        ;; Simple interest calculation: (principal * rate * time) / 10000
        (/ (* (* (get loan-amount loan) interest-rate) blocks-elapsed) u10000)
    )
)

(define-private (get-current-collateral-ratio (loan-id uint))
    (let
        (
            (loan (unwrap! (map-get? loans { loan-id: loan-id }) u0))
            (current-price (var-get oracle-price))
            (collateral-value (* (get collateral-amount loan) current-price))
        )
        (/ (* collateral-value u100) (get loan-amount loan))
    )
)

;; Read-Only Functions
(define-read-only (get-loan-details (loan-id uint))
    (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-current-price)
    (var-get oracle-price)
)

(define-read-only (is-liquidatable (loan-id uint))
    (let
        (
            (current-ratio (get-current-collateral-ratio loan-id))
        )
        (< current-ratio LIQUIDATION_THRESHOLD)
    )
)