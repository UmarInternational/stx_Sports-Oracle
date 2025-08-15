;; ===============================================
;; STACKSPORTS ORACLE - SIMPLIFIED VERSION
;; Sports Prediction Platform on Stacks
;; ===============================================

;; ==========================================
;; CONSTANTS AND ERROR CODES
;; ==========================================

(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-INVALID-PARAMETERS (err u1002))
(define-constant ERR-ALREADY-EXISTS (err u1003))
(define-constant ERR-NOT-FOUND (err u1004))
(define-constant ERR-INSUFFICIENT-FUNDS (err u1005))
(define-constant ERR-CONTRACT-PAUSED (err u1006))
(define-constant ERR-INVALID-VALIDATOR (err u2001))
(define-constant ERR-EVENT-NOT-FINISHED (err u2002))
(define-constant ERR-ALREADY-SUBMITTED (err u2003))
(define-constant ERR-PREDICTION-DEADLINE-PASSED (err u3001))
(define-constant ERR-INVALID-CONFIDENCE (err u3002))
(define-constant ERR-ALREADY-PREDICTED (err u3003))

;; Platform Constants
(define-constant MIN-STAKE u1000000) ;; 1 STX
(define-constant MAX-CONFIDENCE u100)
(define-constant MIN-ORACLE-CONFIRMATIONS u3)
(define-constant PLATFORM-FEE-RATE u5) ;; 5%

;; ==========================================
;; DATA VARIABLES
;; ==========================================

(define-data-var contract-owner principal tx-sender)
(define-data-var emergency-pause bool false)
(define-data-var next-event-id uint u1)
(define-data-var platform-fee-collected uint u0)

;; ==========================================
;; NFT DEFINITION
;; ==========================================

(define-non-fungible-token stacksports-predictor-nft uint)

;; ==========================================
;; DATA MAPS
;; ==========================================

;; Sports Events
(define-map sports-events
  uint ;; event-id
  {
    home-team: (string-ascii 64),
    away-team: (string-ascii 64),
    sport: (string-ascii 32),
    start-time: uint,
    end-time: uint,
    status: (string-ascii 16) ;; "scheduled", "finished", "cancelled"
  }
)

;; Oracle Validators
(define-map oracle-validators
  principal
  {
    reputation: uint,
    stake-amount: uint,
    is-active: bool
  }
)

;; Oracle Results
(define-map oracle-results
  uint ;; event-id
  {
    home-score: uint,
    away-score: uint,
    winner: (string-ascii 8), ;; "home", "away", "draw"
    status: (string-ascii 16), ;; "pending", "verified"
    primary-submitter: principal,
    confirmations: uint
  }
)

;; User Predictions
(define-map user-predictions
  {user: principal, event-id: uint}
  {
    prediction-type: (string-ascii 16),
    predicted-winner: (string-ascii 8), ;; "home", "away", "draw"
    stake-amount: uint,
    confidence-level: uint,
    submission-time: uint,
    is-correct: bool,
    reward-earned: uint,
    reward-claimed: bool
  }
)

;; Event Prediction Pools
(define-map event-prediction-pools
  uint ;; event-id
  {
    total-staked: uint,
    total-participants: uint,
    platform-fee: uint,
    is-settled: bool
  }
)

;; User Statistics
(define-map user-stats
  principal
  {
    total-predictions: uint,
    correct-predictions: uint,
    total-staked: uint,
    total-winnings: uint,
    reputation-score: uint
  }
)

;; ==========================================
;; PRIVATE HELPER FUNCTIONS
;; ==========================================

(define-private (check-not-paused)
  (if (var-get emergency-pause)
    ERR-CONTRACT-PAUSED
    (ok true)))

;; ==========================================
;; ADMINISTRATIVE FUNCTIONS
;; ==========================================

(define-public (toggle-emergency-pause)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set emergency-pause (not (var-get emergency-pause)))
    (ok (var-get emergency-pause))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)))

;; ==========================================
;; ORACLE SYSTEM FUNCTIONS
;; ==========================================

(define-public (register-oracle-validator (stake-amount uint))
  (begin
    (try! (check-not-paused))
    (asserts! (>= stake-amount (* MIN-STAKE u10)) ERR-INSUFFICIENT-FUNDS)
    (asserts! (is-none (map-get? oracle-validators tx-sender)) ERR-ALREADY-EXISTS)
    
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set oracle-validators tx-sender
      {
        reputation: u1000,
        stake-amount: stake-amount,
        is-active: true
      })
    (ok true)))

(define-public (create-sports-event (home-team (string-ascii 64))
                                   (away-team (string-ascii 64))
                                   (sport (string-ascii 32))
                                   (start-time uint))
  (let ((event-id (var-get next-event-id)))
    (try! (check-not-paused))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> start-time stacks-block-height) ERR-INVALID-PARAMETERS)
    
    (map-set sports-events event-id
      {
        home-team: home-team,
        away-team: away-team,
        sport: sport,
        start-time: start-time,
        end-time: (+ start-time u144), ;; ~24 hours later
        status: "scheduled"
      })
    
    (map-set event-prediction-pools event-id
      {
        total-staked: u0,
        total-participants: u0,
        platform-fee: u0,
        is-settled: false
      })
    
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (submit-oracle-result (event-id uint)
                                   (home-score uint)
                                   (away-score uint))
  (let ((validator-info (unwrap! (map-get? oracle-validators tx-sender) ERR-INVALID-VALIDATOR))
        (event-info (unwrap! (map-get? sports-events event-id) ERR-NOT-FOUND)))
    
    (try! (check-not-paused))
    (asserts! (get is-active validator-info) ERR-INVALID-VALIDATOR)
    (asserts! (> stacks-block-height (get end-time event-info)) ERR-EVENT-NOT-FINISHED)
    (asserts! (is-none (map-get? oracle-results event-id)) ERR-ALREADY-SUBMITTED)
    
    (let ((winner (if (> home-score away-score) "home"
                     (if (< home-score away-score) "away" "draw"))))
      (map-set oracle-results event-id
        {
          home-score: home-score,
          away-score: away-score,
          winner: winner,
          status: "verified",
          primary-submitter: tx-sender,
          confirmations: u1
        })
      
      ;; Auto-settle predictions
      (try! (settle-event-predictions event-id))
      (ok true))))

;; ==========================================
;; PREDICTION SYSTEM FUNCTIONS
;; ==========================================

(define-public (submit-prediction (event-id uint)
                                (predicted-winner (string-ascii 8))
                                (stake-amount uint)
                                (confidence-level uint))
  (let ((event-info (unwrap! (map-get? sports-events event-id) ERR-NOT-FOUND))
        (user-info (default-to {total-predictions: u0, correct-predictions: u0, 
                               total-staked: u0, total-winnings: u0, reputation-score: u1000}
                              (map-get? user-stats tx-sender)))
        (pool-info (unwrap! (map-get? event-prediction-pools event-id) ERR-NOT-FOUND)))
    
    (try! (check-not-paused))
    (asserts! (< stacks-block-height (get start-time event-info)) ERR-PREDICTION-DEADLINE-PASSED)
    (asserts! (>= stake-amount MIN-STAKE) ERR-INSUFFICIENT-FUNDS)
    (asserts! (<= confidence-level MAX-CONFIDENCE) ERR-INVALID-CONFIDENCE)
    (asserts! (is-none (map-get? user-predictions {user: tx-sender, event-id: event-id})) ERR-ALREADY-PREDICTED)
    
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (let ((platform-fee (/ (* stake-amount PLATFORM-FEE-RATE) u100))
          (net-stake (- stake-amount platform-fee)))
      
      (map-set user-predictions {user: tx-sender, event-id: event-id}
        {
          prediction-type: "winner",
          predicted-winner: predicted-winner,
          stake-amount: net-stake,
          confidence-level: confidence-level,
          submission-time: stacks-block-height,
          is-correct: false,
          reward-earned: u0,
          reward-claimed: false
        })
      
      (map-set event-prediction-pools event-id
        (merge pool-info {
          total-staked: (+ (get total-staked pool-info) net-stake),
          total-participants: (+ (get total-participants pool-info) u1),
          platform-fee: (+ (get platform-fee pool-info) platform-fee)
        }))
      
      (map-set user-stats tx-sender
        (merge user-info {
          total-predictions: (+ (get total-predictions user-info) u1),
          total-staked: (+ (get total-staked user-info) net-stake)
        }))
      
      (var-set platform-fee-collected (+ (var-get platform-fee-collected) platform-fee))
      (ok true))))

(define-public (settle-event-predictions (event-id uint))
  (let ((oracle-result (unwrap! (map-get? oracle-results event-id) ERR-NOT-FOUND))
        (pool-info (unwrap! (map-get? event-prediction-pools event-id) ERR-NOT-FOUND)))
    
    (try! (check-not-paused))
    (asserts! (is-eq (get status oracle-result) "verified") ERR-INVALID-PARAMETERS)
    (asserts! (not (get is-settled pool-info)) ERR-ALREADY-EXISTS)
    
    (map-set event-prediction-pools event-id
      (merge pool-info {is-settled: true}))
    
    (ok true)))

(define-public (claim-prediction-reward (event-id uint))
  (let ((prediction-key {user: tx-sender, event-id: event-id})
        (prediction-info (unwrap! (map-get? user-predictions prediction-key) ERR-NOT-FOUND))
        (oracle-result (unwrap! (map-get? oracle-results event-id) ERR-NOT-FOUND))
        (pool-info (unwrap! (map-get? event-prediction-pools event-id) ERR-NOT-FOUND))
        (user-info (unwrap! (map-get? user-stats tx-sender) ERR-NOT-FOUND)))
    
    (try! (check-not-paused))
    (asserts! (get is-settled pool-info) ERR-NOT-FOUND)
    (asserts! (not (get reward-claimed prediction-info)) ERR-ALREADY-EXISTS)
    
    (let ((is-correct (is-eq (get predicted-winner prediction-info) (get winner oracle-result))))
      (if is-correct
        (let ((reward (* (get stake-amount prediction-info) u2))) ;; Simple 2x reward
          (try! (as-contract (stx-transfer? reward tx-sender tx-sender)))
          
          (map-set user-predictions prediction-key
            (merge prediction-info {
              is-correct: true,
              reward-earned: reward,
              reward-claimed: true
            }))
          
          (map-set user-stats tx-sender
            (merge user-info {
              correct-predictions: (+ (get correct-predictions user-info) u1),
              total-winnings: (+ (get total-winnings user-info) reward)
            }))
          
          (ok reward))
        (begin
          (map-set user-predictions prediction-key
            (merge prediction-info {reward-claimed: true}))
          (ok u0))))))

;; ==========================================
;; READ-ONLY FUNCTIONS
;; ==========================================

(define-read-only (get-sports-event (event-id uint))
  (map-get? sports-events event-id))

(define-read-only (get-oracle-result (event-id uint))
  (map-get? oracle-results event-id))

(define-read-only (get-user-prediction (user principal) (event-id uint))
  (map-get? user-predictions {user: user, event-id: event-id}))

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats user))

(define-read-only (get-event-pool (event-id uint))
  (map-get? event-prediction-pools event-id))

(define-read-only (get-contract-owner)
  (var-get contract-owner))

(define-read-only (is-contract-paused)
  (var-get emergency-pause))

(define-read-only (get-platform-fee-collected)
  (var-get platform-fee-collected))

(define-read-only (calculate-accuracy (user principal))
  (let ((stats (map-get? user-stats user)))
    (if (is-some stats)
      (let ((user-data (unwrap-panic stats)))
        (if (> (get total-predictions user-data) u0)
          (/ (* (get correct-predictions user-data) u10000) (get total-predictions user-data))
          u0))
      u0)))

;; ==========================================
;; UTILITY FUNCTIONS
;; ==========================================

(define-public (withdraw-platform-fees (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (let ((amount (var-get platform-fee-collected)))
      (asserts! (> amount u0) ERR-INSUFFICIENT-FUNDS)
      (try! (as-contract (stx-transfer? amount tx-sender recipient)))
      (var-set platform-fee-collected u0)
      (ok amount))))

(define-read-only (get-next-event-id)
  (var-get next-event-id))