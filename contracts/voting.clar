(define-data-var proposal-counter uint u0)
(define-data-var admin principal tx-sender)

(define-map proposals
  uint
  {
    description: (string-ascii 100),
    vote-count: uint,
    is-open: bool
  }
)

(define-map has-voted
  { proposal-id: uint, voter: principal }
  bool
)

;; Create a new proposal
(define-public (create-proposal (desc (string-ascii 100)))
  (begin
    (let ((id (+ (var-get proposal-counter) u1)))
      (var-set proposal-counter id)
      (map-set proposals id {
        description: desc,
        vote-count: u0,
        is-open: true
      })
      (ok id)
    )
  )
)

;; Vote on an open proposal
(define-public (vote (proposal-id uint))
  (begin
    (asserts! (is-some (map-get? proposals proposal-id)) (err u100))
    (let (
      (proposal (unwrap! (map-get? proposals proposal-id) (err u101)))
      (voted? (default-to false (map-get? has-voted { proposal-id: proposal-id, voter: tx-sender })))
    )
      (asserts! (not voted?) (err u102))
      (asserts! (get is-open proposal) (err u103))
      (map-set has-voted { proposal-id: proposal-id, voter: tx-sender } true)
      (map-set proposals proposal-id {
        description: (get description proposal),
        vote-count: (+ (get vote-count proposal) u1),
        is-open: true
      })
      (ok true)
    )
  )
)

;; Close voting (admin only)
(define-public (close-proposal (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u200))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u201))))
      (map-set proposals proposal-id {
        description: (get description proposal),
        vote-count: (get vote-count proposal),
        is-open: false
      })
      (ok true)
    )
  )
)

;; Reopen voting (admin only)
(define-public (reopen-proposal (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u400))
    (let ((proposal (unwrap! (map-get? proposals proposal-id) (err u401))))
      (map-set proposals proposal-id {
        description: (get description proposal),
        vote-count: (get vote-count proposal),
        is-open: true
      })
      (ok true)
    )
  )
)

;; Delete a proposal (admin only)
(define-public (delete-proposal (proposal-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u500))
    (map-delete proposals proposal-id)
    (ok true)
  )
)

;; Transfer admin rights
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u600))
    (var-set admin new-admin)
    (ok true)
  )
)

;; Read proposal details
(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

;; Read voting result (only if closed)
(define-read-only (get-results (proposal-id uint))
  (let ((proposal (map-get? proposals proposal-id)))
    (match proposal
      proposal-data
      (if (is-eq (get is-open proposal-data) false)
        (ok {
          description: (get description proposal-data),
          vote-count: (get vote-count proposal-data)
        })
        (err u300)
      )
      (err u301)
    )
  )
)

;; Check if an address has voted on a proposal
(define-read-only (has-voted? (proposal-id uint) (user principal))
  (ok (default-to false (map-get? has-voted { proposal-id: proposal-id, voter: user })))
)
