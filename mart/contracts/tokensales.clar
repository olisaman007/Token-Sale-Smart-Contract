;; A token sale contract with multiple phases and admin controls

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SALE-NOT-ACTIVE (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-MAX-MINT-REACHED (err u103))
(define-constant ERR-INVALID-PHASE (err u104))
(define-constant ERR-ALREADY-CLAIMED (err u105))
(define-constant ERR-NOT-WHITELISTED (err u106))
(define-constant ERR-PHASE-ACTIVE (err u107))
(define-constant ERR-INVALID-AMOUNT (err u108))

;; Token definitions
(define-fungible-token sale-token)

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var token-name (string-ascii 32) "ExampleToken")
(define-data-var token-symbol (string-ascii 10) "EXT")
(define-data-var token-decimals uint u6)
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var total-supply uint u0)
(define-data-var max-supply uint u1000000000000) ;; 1 million with 6 decimals

;; Sale configuration
(define-data-var sale-active bool false)
(define-data-var current-phase uint u0) ;; 0 = not started, 1 = whitelist, 2 = public
(define-data-var whitelist-price uint u500000) ;; 0.5 STX with 6 decimals
(define-data-var public-price uint u1000000) ;; 1 STX with 6 decimals
(define-data-var max-per-address uint u10000000000) ;; 10,000 tokens with 6 decimals
(define-data-var phase-1-start uint u0)
(define-data-var phase-1-end uint u0)
(define-data-var phase-2-start uint u0)
(define-data-var phase-2-end uint u0)

;; Maps
(define-map whitelist principal bool)
(define-map purchases principal uint)
(define-map claimed principal bool)

;; Read-only functions

(define-read-only (get-token-name)
  (var-get token-name)
)

(define-read-only (get-token-symbol)
  (var-get token-symbol)
)

(define-read-only (get-token-decimals)
  (var-get token-decimals)
)

(define-read-only (get-token-uri-simple)
  (var-get token-uri)
)

(define-read-only (get-total-supply)
  (var-get total-supply)
)

(define-read-only (get-max-supply)
  (var-get max-supply)
)

(define-read-only (get-balance (account principal))
  (ft-get-balance sale-token account)
)

(define-read-only (get-sale-status)
  (var-get sale-active)
)

(define-read-only (get-current-phase)
  (var-get current-phase)
)

(define-read-only (get-current-price)
  (if (is-eq (var-get current-phase) u1)
    (var-get whitelist-price)
    (var-get public-price)
  )
)

(define-read-only (get-phase-times)
  {
    phase-1-start: (var-get phase-1-start),
    phase-1-end: (var-get phase-1-end),
    phase-2-start: (var-get phase-2-start),
    phase-2-end: (var-get phase-2-end)
  }
)

(define-read-only (is-whitelisted (address principal))
  (default-to false (map-get? whitelist address))
)

(define-read-only (get-purchased-amount (address principal))
  (default-to u0 (map-get? purchases address))
)

(define-read-only (has-claimed (address principal))
  (default-to false (map-get? claimed address))
)

;; Private functions

(define-private (check-is-owner)
  (if (is-eq tx-sender (var-get contract-owner))
    (ok true)
    ERR-NOT-AUTHORIZED
  )
)

(define-private (check-sale-active)
  (if (var-get sale-active)
    (ok true)
    ERR-SALE-NOT-ACTIVE
  )
)

(define-private (check-can-purchase (amount uint))
  (let (
    (phase (var-get current-phase))
    (purchased (default-to u0 (map-get? purchases tx-sender)))
    (new-total (+ purchased amount))
  )
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (or (is-eq phase u1) (is-eq phase u2)) ERR-INVALID-PHASE)
    (asserts! (<= new-total (var-get max-per-address)) ERR-MAX-MINT-REACHED)
    
    ;; Check whitelist for phase 1
    (if (is-eq phase u1)
      (asserts! (default-to false (map-get? whitelist tx-sender)) ERR-NOT-WHITELISTED)
      true
    )
    
    (ok true)
  )
)

(define-private (calculate-cost (amount uint))
  (let (
    (price (if (is-eq (var-get current-phase) u1)
      (var-get whitelist-price)
      (var-get public-price)
    ))
  )
    (* amount price)
  )
)

;; Public functions

;; Token purchase function
(define-public (purchase (amount uint))
  (let (
    (cost (calculate-cost amount))
    (current-purchased (default-to u0 (map-get? purchases tx-sender)))
    (new-total-supply (+ (var-get total-supply) amount))
  )
    (try! (check-sale-active))
    (try! (check-can-purchase amount))
    
    ;; Check if we have enough supply
    (asserts! (<= new-total-supply (var-get max-supply)) ERR-MAX-MINT-REACHED)
    
    ;; Transfer STX from buyer to contract
    (try! (stx-transfer? cost tx-sender (as-contract tx-sender)))
    
    ;; Mint tokens to buyer
    (try! (ft-mint? sale-token amount tx-sender))
    
    ;; Update state
    (map-set purchases tx-sender (+ current-purchased amount))
    (var-set total-supply new-total-supply)
    
    (ok amount)
  )
)

;; Admin functions

;; Initialize the token
(define-public (initialize (name (string-ascii 32)) (symbol (string-ascii 10)) (decimals uint) (uri (optional (string-utf8 256))))
  (begin
    (try! (check-is-owner))
    (var-set token-name name)
    (var-set token-symbol symbol)
    (var-set token-decimals decimals)
    (var-set token-uri uri)
    (ok true)
  )
)

;; Set sale configuration
(define-public (configure-sale (whitelist-price-arg uint) (public-price-arg uint) (max-per-address-arg uint))
  (begin
    (try! (check-is-owner))
    (var-set whitelist-price whitelist-price-arg)
    (var-set public-price public-price-arg)
    (var-set max-per-address max-per-address-arg)
    (ok true)
  )
)

;; Set phase times
(define-public (set-phase-times (p1-start uint) (p1-end uint) (p2-start uint) (p2-end uint))
  (begin
    (try! (check-is-owner))
    (var-set phase-1-start p1-start)
    (var-set phase-1-end p1-end)
    (var-set phase-2-start p2-start)
    (var-set phase-2-end p2-end)
    (ok true)
  )
)

;; Add addresses to whitelist
(define-public (add-to-whitelist (addresses (list 50 principal)))
  (begin
    (try! (check-is-owner))
    (map add-address addresses)
    (ok true)
  )
)

(define-private (add-address (address principal))
  (map-set whitelist address true)
)

;; Remove addresses from whitelist
(define-public (remove-from-whitelist (addresses (list 50 principal)))
  (begin
    (try! (check-is-owner))
    (map remove-address addresses)
    (ok true)
  )
)

(define-private (remove-address (address principal))
  (map-delete whitelist address)
)

;; Start sale
(define-public (start-sale (phase uint))
  (begin
    (try! (check-is-owner))
    (asserts! (or (is-eq phase u1) (is-eq phase u2)) ERR-INVALID-PHASE)
    (var-set sale-active true)
    (var-set current-phase phase)
    (ok true)
  )
)

;; Pause sale
(define-public (pause-sale)
  (begin
    (try! (check-is-owner))
    (var-set sale-active false)
    (ok true)
  )
)

;; Change phase
(define-public (change-phase (phase uint))
  (begin
    (try! (check-is-owner))
    (asserts! (or (is-eq phase u1) (is-eq phase u2)) ERR-INVALID-PHASE)
    (var-set current-phase phase)
    (ok true)
  )
)

;; Withdraw funds
(define-public (withdraw-funds (amount uint) (recipient principal))
  (begin
    (try! (check-is-owner))
    (as-contract (stx-transfer? amount tx-sender recipient))
  )
)

;; Set max supply
(define-public (set-max-supply (new-max-supply uint))
  (begin
    (try! (check-is-owner))
    (asserts! (>= new-max-supply (var-get total-supply)) ERR-INVALID-AMOUNT)
    (var-set max-supply new-max-supply)
    (ok true)
  )
)

;; Transfer ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (try! (check-is-owner))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; SIP-010 compliance functions

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (match (ft-transfer? sale-token amount sender recipient)
      success (begin
        (match memo
          some-memo (begin (print some-memo) none)
          none
        )
        (ok success)
      )
      error (err error)
    )
  )
)

(define-read-only (get-token-uri-detailed)
  (ok (var-get token-uri))
)

(define-read-only (get-name)
  (ok (var-get token-name))
)

(define-read-only (get-symbol)
  (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
  (ok (var-get token-decimals))
)

(define-read-only (get-balance-of (who principal))
  (ok (ft-get-balance sale-token who))
)

(define-read-only (get-total-supply-ft)
  (ok (var-get total-supply))
)