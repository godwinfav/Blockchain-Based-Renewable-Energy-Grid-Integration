;; Generator Verification Contract
;; Validates and manages renewable energy sources

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_GENERATOR_EXISTS (err u101))
(define-constant ERR_GENERATOR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CAPACITY (err u103))

;; Generator types
(define-constant SOLAR u1)
(define-constant WIND u2)
(define-constant HYDRO u3)
(define-constant GEOTHERMAL u4)

;; Data structures
(define-map generators
  { generator-id: uint }
  {
    owner: principal,
    generator-type: uint,
    capacity: uint,
    location: (string-ascii 50),
    verified: bool,
    registration-block: uint
  }
)

(define-map generator-stats
  { generator-id: uint }
  {
    total-production: uint,
    uptime-percentage: uint,
    last-maintenance: uint
  }
)

(define-data-var next-generator-id uint u1)

;; Register a new renewable energy generator
(define-public (register-generator (generator-type uint) (capacity uint) (location (string-ascii 50)))
  (let ((generator-id (var-get next-generator-id)))
    (asserts! (> capacity u0) ERR_INVALID_CAPACITY)
    (asserts! (or (is-eq generator-type SOLAR)
                  (is-eq generator-type WIND)
                  (is-eq generator-type HYDRO)
                  (is-eq generator-type GEOTHERMAL)) ERR_INVALID_CAPACITY)

    (map-set generators
      { generator-id: generator-id }
      {
        owner: tx-sender,
        generator-type: generator-type,
        capacity: capacity,
        location: location,
        verified: false,
        registration-block: block-height
      }
    )

    (map-set generator-stats
      { generator-id: generator-id }
      {
        total-production: u0,
        uptime-percentage: u100,
        last-maintenance: block-height
      }
    )

    (var-set next-generator-id (+ generator-id u1))
    (ok generator-id)
  )
)

;; Verify a generator (admin only)
(define-public (verify-generator (generator-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? generators { generator-id: generator-id })
      generator-data
      (begin
        (map-set generators
          { generator-id: generator-id }
          (merge generator-data { verified: true })
        )
        (ok true)
      )
      ERR_GENERATOR_NOT_FOUND
    )
  )
)

;; Update generator production stats
(define-public (update-production (generator-id uint) (production uint))
  (match (map-get? generators { generator-id: generator-id })
    generator-data
    (begin
      (asserts! (is-eq (get owner generator-data) tx-sender) ERR_UNAUTHORIZED)
      (match (map-get? generator-stats { generator-id: generator-id })
        stats-data
        (begin
          (map-set generator-stats
            { generator-id: generator-id }
            (merge stats-data { total-production: (+ (get total-production stats-data) production) })
          )
          (ok true)
        )
        ERR_GENERATOR_NOT_FOUND
      )
    )
    ERR_GENERATOR_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-generator (generator-id uint))
  (map-get? generators { generator-id: generator-id })
)

(define-read-only (get-generator-stats (generator-id uint))
  (map-get? generator-stats { generator-id: generator-id })
)

(define-read-only (is-generator-verified (generator-id uint))
  (match (map-get? generators { generator-id: generator-id })
    generator-data (get verified generator-data)
    false
  )
)
