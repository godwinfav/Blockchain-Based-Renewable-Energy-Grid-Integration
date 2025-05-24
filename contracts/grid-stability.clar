;; Grid Stability Contract
;; Manages system balance and stability

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_INVALID_PARAMETERS (err u301))
(define-constant ERR_GRID_UNSTABLE (err u302))

;; Grid status constants
(define-constant STABLE u1)
(define-constant WARNING u2)
(define-constant CRITICAL u3)
(define-constant EMERGENCY u4)

;; Grid state
(define-data-var current-load uint u0)
(define-data-var current-generation uint u0)
(define-data-var grid-frequency uint u5000) ;; 50.00 Hz represented as 5000
(define-data-var grid-status uint STABLE)
(define-data-var last-update uint u0)

;; Load balancing events
(define-map stability-events
  { event-id: uint }
  {
    timestamp: uint,
    event-type: uint,
    load: uint,
    generation: uint,
    frequency: uint,
    action-taken: (string-ascii 100)
  }
)

(define-data-var next-event-id uint u1)

;; Frequency thresholds (in hundredths of Hz)
(define-constant MIN_FREQUENCY u4950) ;; 49.50 Hz
(define-constant MAX_FREQUENCY u5050) ;; 50.50 Hz
(define-constant CRITICAL_LOW u4900)  ;; 49.00 Hz
(define-constant CRITICAL_HIGH u5100) ;; 51.00 Hz

;; Update grid parameters
(define-public (update-grid-state (load uint) (generation uint) (frequency uint))
  (begin
    (asserts! (> load u0) ERR_INVALID_PARAMETERS)
    (asserts! (> generation u0) ERR_INVALID_PARAMETERS)
    (asserts! (> frequency u4000) ERR_INVALID_PARAMETERS) ;; Minimum 40 Hz
    (asserts! (< frequency u6000) ERR_INVALID_PARAMETERS) ;; Maximum 60 Hz

    (var-set current-load load)
    (var-set current-generation generation)
    (var-set grid-frequency frequency)
    (var-set last-update block-height)

    ;; Determine grid status
    (let ((new-status (calculate-grid-status load generation frequency)))
      (var-set grid-status new-status)

      ;; Log stability event if not stable
      (if (not (is-eq new-status STABLE))
        (log-stability-event new-status load generation frequency)
        (ok true)
      )
    )
  )
)

;; Calculate grid status based on parameters
(define-private (calculate-grid-status (load uint) (generation uint) (frequency uint))
  (let ((load-generation-ratio (if (> generation u0) (/ (* load u100) generation) u200))
        (frequency-ok (and (>= frequency MIN_FREQUENCY) (<= frequency MAX_FREQUENCY))))

    (if (or (<= frequency CRITICAL_LOW) (>= frequency CRITICAL_HIGH))
      EMERGENCY
      (if (or (not frequency-ok) (> load-generation-ratio u120) (< load-generation-ratio u80))
        CRITICAL
        (if (or (> load-generation-ratio u110) (< load-generation-ratio u90))
          WARNING
          STABLE
        )
      )
    )
  )
)

;; Log stability events
(define-private (log-stability-event (event-type uint) (load uint) (generation uint) (frequency uint))
  (let ((event-id (var-get next-event-id))
        (action (get-recommended-action event-type load generation frequency)))

    (map-set stability-events
      { event-id: event-id }
      {
        timestamp: block-height,
        event-type: event-type,
        load: load,
        generation: generation,
        frequency: frequency,
        action-taken: action
      }
    )

    (var-set next-event-id (+ event-id u1))
    (ok true)
  )
)

;; Get recommended action based on grid status
(define-private (get-recommended-action (status uint) (load uint) (generation uint) (frequency uint))
  (if (is-eq status EMERGENCY)
    "EMERGENCY_SHUTDOWN"
    (if (is-eq status CRITICAL)
      (if (> load generation) "INCREASE_GENERATION" "REDUCE_LOAD")
      (if (is-eq status WARNING)
        "MONITOR_CLOSELY"
        "NO_ACTION"
      )
    )
  )
)

;; Emergency shutdown (admin only)
(define-public (emergency-shutdown)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (var-set grid-status EMERGENCY)
    (log-stability-event EMERGENCY (var-get current-load) (var-get current-generation) (var-get grid-frequency))
  )
)

;; Read-only functions
(define-read-only (get-grid-status)
  {
    load: (var-get current-load),
    generation: (var-get current-generation),
    frequency: (var-get grid-frequency),
    status: (var-get grid-status),
    last-update: (var-get last-update)
  }
)

(define-read-only (get-stability-event (event-id uint))
  (map-get? stability-events { event-id: event-id })
)

(define-read-only (is-grid-stable)
  (is-eq (var-get grid-status) STABLE)
)

(define-read-only (get-load-generation-balance)
  (let ((load (var-get current-load))
        (generation (var-get current-generation)))
    (if (> generation u0)
      (/ (* load u100) generation)
      u0
    )
  )
)
