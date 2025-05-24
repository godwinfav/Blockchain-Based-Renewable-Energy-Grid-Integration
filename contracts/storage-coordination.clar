;; Storage Coordination Contract
;; Optimizes battery and energy storage usage

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_STORAGE_NOT_FOUND (err u401))
(define-constant ERR_INSUFFICIENT_CAPACITY (err u402))
(define-constant ERR_INVALID_PARAMETERS (err u403))

;; Storage types
(define-constant BATTERY u1)
(define-constant PUMPED_HYDRO u2)
(define-constant COMPRESSED_AIR u3)
(define-constant THERMAL u4)

;; Storage unit data
(define-map storage-units
  { storage-id: uint }
  {
    owner: principal,
    storage-type: uint,
    total-capacity: uint,
    current-charge: uint,
    max-charge-rate: uint,
    max-discharge-rate: uint,
    efficiency: uint,
    location: (string-ascii 50),
    active: bool
  }
)

;; Storage operations log
(define-map storage-operations
  { operation-id: uint }
  {
    storage-id: uint,
    operation-type: (string-ascii 20),
    amount: uint,
    timestamp: uint,
    grid-demand: uint,
    operator: principal
  }
)

(define-data-var next-storage-id uint u1)
(define-data-var next-operation-id uint u1)

;; Register a new storage unit
(define-public (register-storage (storage-type uint) (total-capacity uint) (max-charge-rate uint) (max-discharge-rate uint) (efficiency uint) (location (string-ascii 50)))
  (let ((storage-id (var-get next-storage-id)))
    (asserts! (> total-capacity u0) ERR_INVALID_PARAMETERS)
    (asserts! (> max-charge-rate u0) ERR_INVALID_PARAMETERS)
    (asserts! (> max-discharge-rate u0) ERR_INVALID_PARAMETERS)
    (asserts! (<= efficiency u100) ERR_INVALID_PARAMETERS)

    (map-set storage-units
      { storage-id: storage-id }
      {
        owner: tx-sender,
        storage-type: storage-type,
        total-capacity: total-capacity,
        current-charge: u0,
        max-charge-rate: max-charge-rate,
        max-discharge-rate: max-discharge-rate,
        efficiency: efficiency,
        location: location,
        active: true
      }
    )

    (var-set next-storage-id (+ storage-id u1))
    (ok storage-id)
  )
)

;; Charge storage unit
(define-public (charge-storage (storage-id uint) (amount uint))
  (match (map-get? storage-units { storage-id: storage-id })
    storage-data
    (let ((current-charge (get current-charge storage-data))
          (total-capacity (get total-capacity storage-data))
          (max-charge-rate (get max-charge-rate storage-data))
          (efficiency (get efficiency storage-data))
          (effective-amount (/ (* amount efficiency) u100)))

      (asserts! (get active storage-data) ERR_INVALID_PARAMETERS)
      (asserts! (<= amount max-charge-rate) ERR_INVALID_PARAMETERS)
      (asserts! (<= (+ current-charge effective-amount) total-capacity) ERR_INSUFFICIENT_CAPACITY)

      (map-set storage-units
        { storage-id: storage-id }
        (merge storage-data { current-charge: (+ current-charge effective-amount) })
      )

      (log-operation storage-id "CHARGE" amount)
    )
    ERR_STORAGE_NOT_FOUND
  )
)

;; Discharge storage unit
(define-public (discharge-storage (storage-id uint) (amount uint))
  (match (map-get? storage-units { storage-id: storage-id })
    storage-data
    (let ((current-charge (get current-charge storage-data))
          (max-discharge-rate (get max-discharge-rate storage-data)))

      (asserts! (get active storage-data) ERR_INVALID_PARAMETERS)
      (asserts! (<= amount max-discharge-rate) ERR_INVALID_PARAMETERS)
      (asserts! (>= current-charge amount) ERR_INSUFFICIENT_CAPACITY)

      (map-set storage-units
        { storage-id: storage-id }
        (merge storage-data { current-charge: (- current-charge amount) })
      )

      (log-operation storage-id "DISCHARGE" amount)
    )
    ERR_STORAGE_NOT_FOUND
  )
)

;; Optimize storage based on grid demand
(define-public (optimize-storage (grid-demand uint) (available-generation uint))
  (let ((demand-surplus (if (> available-generation grid-demand)
                          (- available-generation grid-demand)
                          u0))
        (demand-deficit (if (> grid-demand available-generation)
                          (- grid-demand available-generation)
                          u0)))

    (if (> demand-surplus u0)
      ;; Excess generation - charge storage
      (ok { action: "CHARGE", amount: demand-surplus })
      (if (> demand-deficit u0)
        ;; Deficit - discharge storage
        (ok { action: "DISCHARGE", amount: demand-deficit })
        ;; Balanced - no action needed
        (ok { action: "MAINTAIN", amount: u0 })
      )
    )
  )
)

;; Log storage operation
(define-private (log-operation (storage-id uint) (operation-type (string-ascii 20)) (amount uint))
  (let ((operation-id (var-get next-operation-id)))
    (map-set storage-operations
      { operation-id: operation-id }
      {
        storage-id: storage-id,
        operation-type: operation-type,
        amount: amount,
        timestamp: block-height,
        grid-demand: u0, ;; Would be passed from grid contract
        operator: tx-sender
      }
    )

    (var-set next-operation-id (+ operation-id u1))
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-storage-unit (storage-id uint))
  (map-get? storage-units { storage-id: storage-id })
)

(define-read-only (get-storage-operation (operation-id uint))
  (map-get? storage-operations { operation-id: operation-id })
)

(define-read-only (get-total-storage-capacity)
  ;; This would iterate through all storage units in a real implementation
  u0
)

(define-read-only (get-total-stored-energy)
  ;; This would sum all current charges in a real implementation
  u0
)

(define-read-only (calculate-storage-efficiency (storage-id uint))
  (match (map-get? storage-units { storage-id: storage-id })
    storage-data (get efficiency storage-data)
    u0
  )
)
