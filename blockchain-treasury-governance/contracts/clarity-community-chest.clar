;; Community Treasury Smart Contract

;; Error codes
(define-constant ERROR-NOT-AUTHORIZED (err u100))
(define-constant ERROR-TREASURY-BALANCE-TOO-LOW (err u101))
(define-constant ERROR-INVALID-AMOUNT (err u102))
(define-constant ERROR-PROPOSAL-NOT-FOUND (err u103))
(define-constant ERROR-DUPLICATE-VOTE (err u104))
(define-constant ERROR-VOTING-PERIOD-EXPIRED (err u105))
(define-constant ERROR-INSUFFICIENT-PROPOSAL-DEPOSIT (err u106))
(define-constant ERROR-INVALID-RECIPIENT-ADDRESS (err u107))
(define-constant ERROR-INVALID-PROPOSAL-DESCRIPTION (err u108))
(define-constant ERROR-INVALID-ADMIN-ADDRESS (err u109))
(define-constant ERROR-PROPOSAL-IN-COOLDOWN (err u110))
(define-constant ERROR-PROPOSAL-IN-TIMELOCK (err u111))
(define-constant ERROR-BELOW-MINIMUM-PROPOSAL-AMOUNT (err u112))
(define-constant ERROR-CANNOT-CANCEL (err u113))

;; Constants
(define-constant VOTING-DURATION-BLOCKS u10000)
(define-constant REQUIRED-PROPOSAL-DEPOSIT u1000000)
(define-constant MINIMUM-VOTES-FOR-QUORUM u500)
(define-constant MINIMUM-APPROVAL-PERCENTAGE u510)
(define-constant PROPOSAL-COOLDOWN-BLOCKS u1000)
(define-constant MINIMUM-PROPOSAL-AMOUNT u100000)
(define-constant TIMELOCK-PERIOD-BLOCKS u144) ;; ~24 hours in blocks
(define-constant EVENT-TYPE-PROPOSAL-CREATED u1)
(define-constant EVENT-TYPE-VOTE-CAST u2)
(define-constant EVENT-TYPE-PROPOSAL-EXECUTED u3)
(define-constant EVENT-TYPE-PROPOSAL-CANCELLED u4)
(define-constant EVENT-TYPE-FUNDS-DEPOSITED u5)
(define-constant EVENT-TYPE-EMERGENCY-WITHDRAWAL u6)

;; Data vars
(define-data-var treasury-balance uint u0)
(define-data-var proposal-counter uint u0)
(define-data-var treasury-admin-address principal tx-sender)
(define-data-var last-proposal-block uint u0)

;; Maps
(define-map active-proposals
    uint
    {
        creator-address: principal,
        withdrawal-amount: uint,
        recipient-address: principal,
        proposal-text: (string-utf8 256),
        yes-vote-count: uint,
        no-vote-count: uint,
        creation-block-height: uint,
        is-executed: bool,
        is-cancelled: bool,
        deposit-amount: uint,
        execution-block: uint
    }
)

(define-map voter-registry
    {proposal-id: uint, voter-address: principal}
    bool
)

(define-map member-deposits principal uint)

;; Events
(define-private (emit-event (event-type uint) (proposal-id uint) (data principal))
    (print {event-type: event-type, proposal-id: proposal-id, triggered-by: data})
)

;; Read-only functions
(define-read-only (get-treasury-balance)
    (var-get treasury-balance)
)

(define-read-only (get-proposal-info (proposal-id uint))
    (map-get? active-proposals proposal-id)
)

(define-read-only (has-member-voted (proposal-id uint) (voter-address principal))
    (default-to false (map-get? voter-registry 
        {proposal-id: proposal-id, voter-address: voter-address}))
)

(define-read-only (get-member-deposit-amount (member-address principal))
    (default-to u0 (map-get? member-deposits member-address))
)

(define-read-only (check-proposal-quorum (proposal-id uint))
    (let (
        (proposal-data (unwrap! (get-proposal-info proposal-id) false))
    )
    (has-reached-quorum 
        (get yes-vote-count proposal-data) 
        (get no-vote-count proposal-data))
    )
)

(define-read-only (is-proposal-executable (proposal-id uint))
    (let (
        (proposal-data (unwrap! (get-proposal-info proposal-id) false))
        (current-block block-height)
    )
    (and
        (check-proposal-quorum proposal-id)
        (>= current-block (+ (get execution-block proposal-data) TIMELOCK-PERIOD-BLOCKS))
        (not (get is-executed proposal-data))
        (not (get is-cancelled proposal-data))
    ))
)

;; Private functions
(define-private (is-voting-period-active (proposal-id uint))
    (let (
        (proposal-data (unwrap! (get-proposal-info proposal-id) false))
        (current-block-height block-height)
    )
    (and
        (>= current-block-height (get creation-block-height proposal-data))
        (< current-block-height (+ (get creation-block-height proposal-data) VOTING-DURATION-BLOCKS))
        (not (get is-executed proposal-data))
        (not (get is-cancelled proposal-data))
    ))
)

(define-private (has-reached-quorum (yes-votes uint) (no-votes uint))
    (let (
        (total-votes (+ yes-votes no-votes))
    )
    (and
        (>= total-votes MINIMUM-VOTES-FOR-QUORUM)
        (>= (* yes-votes u1000) (* MINIMUM-APPROVAL-PERCENTAGE total-votes))
    ))
)

(define-private (is-recipient-valid (recipient-address principal))
    (and
        (not (is-eq recipient-address (as-contract tx-sender)))
        (not (is-eq recipient-address tx-sender))
        true
    )
)

(define-private (is-description-valid (description-text (string-utf8 256)))
    (let ((description-length (len description-text)))
        (and
            (> description-length u0)
            (<= description-length u256)
            true
        )
    )
)

;; Public functions
(define-public (deposit-funds)
    (let (
        (deposit-amount (stx-get-balance tx-sender))
        (previous-deposit (get-member-deposit-amount tx-sender))
    )
    (begin
        (asserts! (> deposit-amount u0) ERROR-INVALID-AMOUNT)
        (try! (stx-transfer? deposit-amount tx-sender (as-contract tx-sender)))
        (var-set treasury-balance (+ (var-get treasury-balance) deposit-amount))
        (map-set member-deposits tx-sender (+ previous-deposit deposit-amount))
        (emit-event EVENT-TYPE-FUNDS-DEPOSITED u0 tx-sender)
        (ok deposit-amount)
    ))
)

(define-public (create-proposal (withdrawal-amount uint) (recipient-address principal) (proposal-text (string-utf8 256)))
    (let (
        (proposal-id (var-get proposal-counter))
        (current-block block-height)
    )
    (begin
        ;; Input validation
        (asserts! (is-recipient-valid recipient-address) ERROR-INVALID-RECIPIENT-ADDRESS)
        (asserts! (is-description-valid proposal-text) ERROR-INVALID-PROPOSAL-DESCRIPTION)
        (asserts! (>= withdrawal-amount MINIMUM-PROPOSAL-AMOUNT) ERROR-BELOW-MINIMUM-PROPOSAL-AMOUNT)
        (asserts! (<= withdrawal-amount (var-get treasury-balance)) ERROR-TREASURY-BALANCE-TOO-LOW)
        (asserts! (> (- current-block (var-get last-proposal-block)) PROPOSAL-COOLDOWN-BLOCKS) ERROR-PROPOSAL-IN-COOLDOWN)
        
        ;; Process deposit
        (try! (stx-transfer? REQUIRED-PROPOSAL-DEPOSIT tx-sender (as-contract tx-sender)))
        
        ;; Create proposal
        (map-set active-proposals proposal-id {
            creator-address: tx-sender,
            withdrawal-amount: withdrawal-amount,
            recipient-address: recipient-address,
            proposal-text: proposal-text,
            yes-vote-count: u0,
            no-vote-count: u0,
            creation-block-height: current-block,
            is-executed: false,
            is-cancelled: false,
            deposit-amount: REQUIRED-PROPOSAL-DEPOSIT,
            execution-block: current-block
        })
        
        (var-set proposal-counter (+ proposal-id u1))
        (var-set last-proposal-block current-block)
        (emit-event EVENT-TYPE-PROPOSAL-CREATED proposal-id tx-sender)
        (ok proposal-id)
    ))
)

(define-public (vote-on-proposal (proposal-id uint) (vote-in-favor bool))
    (let (
        (proposal-data (unwrap! (get-proposal-info proposal-id) ERROR-PROPOSAL-NOT-FOUND))
    )
    (begin
        (asserts! (is-voting-period-active proposal-id) ERROR-VOTING-PERIOD-EXPIRED)
        (asserts! (not (has-member-voted proposal-id tx-sender)) ERROR-DUPLICATE-VOTE)
        
        (map-set voter-registry 
            {proposal-id: proposal-id, voter-address: tx-sender} 
            true)
        
        (if vote-in-favor
            (map-set active-proposals proposal-id 
                (merge proposal-data {
                    yes-vote-count: (+ (get yes-vote-count proposal-data) u1),
                    execution-block: block-height
                }))
            (map-set active-proposals proposal-id 
                (merge proposal-data {no-vote-count: (+ (get no-vote-count proposal-data) u1)}))
        )
        
        (emit-event EVENT-TYPE-VOTE-CAST proposal-id tx-sender)
        (ok true)
    ))
)

(define-public (cancel-proposal (proposal-id uint))
    (let (
        (proposal-data (unwrap! (get-proposal-info proposal-id) ERROR-PROPOSAL-NOT-FOUND))
    )
    (begin
        (asserts! (is-eq tx-sender (get creator-address proposal-data)) ERROR-NOT-AUTHORIZED)
        (asserts! (is-voting-period-active proposal-id) ERROR-VOTING-PERIOD-EXPIRED)
        (asserts! (not (get is-cancelled proposal-data)) ERROR-CANNOT-CANCEL)
        
        ;; Return deposit to proposer
        (try! (as-contract (stx-transfer? (get deposit-amount proposal-data)
                                        tx-sender
                                        (get creator-address proposal-data))))
        
        ;; Mark proposal as cancelled
        (map-set active-proposals proposal-id 
            (merge proposal-data {is-cancelled: true}))
            
        (emit-event EVENT-TYPE-PROPOSAL-CANCELLED proposal-id tx-sender)
        (ok true)
    ))
)

(define-public (process-approved-proposal (proposal-id uint))
    (let (
        (proposal-data (unwrap! (get-proposal-info proposal-id) ERROR-PROPOSAL-NOT-FOUND))
    )
    (begin
        (asserts! (not (get is-executed proposal-data)) ERROR-VOTING-PERIOD-EXPIRED)
        (asserts! (not (get is-cancelled proposal-data)) ERROR-CANNOT-CANCEL)
        (asserts! (has-reached-quorum 
            (get yes-vote-count proposal-data) 
            (get no-vote-count proposal-data)) 
            ERROR-NOT-AUTHORIZED)
        (asserts! (>= block-height (+ (get execution-block proposal-data) TIMELOCK-PERIOD-BLOCKS))
            ERROR-PROPOSAL-IN-TIMELOCK)
        
        ;; Execute the transfer
        (try! (as-contract (stx-transfer? (get withdrawal-amount proposal-data) 
                                        (as-contract tx-sender) 
                                        (get recipient-address proposal-data))))
        
        ;; Update treasury balance
        (var-set treasury-balance 
            (- (var-get treasury-balance) (get withdrawal-amount proposal-data)))
        
        ;; Return deposit to proposer
        (try! (as-contract (stx-transfer? (get deposit-amount proposal-data)
                                        tx-sender
                                        (get creator-address proposal-data))))
        
        ;; Mark proposal as executed
        (map-set active-proposals proposal-id 
            (merge proposal-data {is-executed: true}))
            
        (emit-event EVENT-TYPE-PROPOSAL-EXECUTED proposal-id tx-sender)
        (ok true)
    ))
)

;; Admin functions
(define-public (update-admin-address (new-admin-address principal))
    (begin
        (asserts! (is-eq tx-sender (var-get treasury-admin-address)) ERROR-NOT-AUTHORIZED)
        (asserts! (not (is-eq new-admin-address (as-contract tx-sender))) ERROR-INVALID-ADMIN-ADDRESS)
        (var-set treasury-admin-address new-admin-address)
        (ok true)
    ))

;; Emergency functions
(define-public (emergency-withdrawal)
    (begin
        (asserts! (is-eq tx-sender (var-get treasury-admin-address)) ERROR-NOT-AUTHORIZED)
        (asserts! (> (var-get treasury-balance) u0) ERROR-TREASURY-BALANCE-TOO-LOW)
        (try! (as-contract (stx-transfer? (var-get treasury-balance)
                                  tx-sender
                                  (var-get treasury-admin-address))))
        (var-set treasury-balance u0)
        (emit-event EVENT-TYPE-EMERGENCY-WITHDRAWAL u0 tx-sender)
        (ok true)
    ))