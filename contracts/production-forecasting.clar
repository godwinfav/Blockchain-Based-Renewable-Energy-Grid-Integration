;; Production Forecasting Contract
;; Predicts renewable energy generation patterns

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_INVALID_FORECAST (err u201))
(define-constant ERR_FORECAST_NOT_FOUND (err u202))

;; Weather conditions
(define-constant SUNNY u1)
(define-constant CLOUDY u2)
(define-constant WINDY u3)
(define-constant RAINY u4)

;; Forecast data structure
(define-map forecasts
  { generator-id: uint, forecast-period: uint }
  {
    predicted-output: uint,
    weather-condition: uint,
    confidence-level: uint,
    created-at: uint,
    forecaster: principal
  }
)

(define-map historical-accuracy
  { forecaster: principal }
  {
    total-forecasts: uint,
    accurate-forecasts: uint,
    accuracy-percentage: uint
  }
)

;; Submit a production forecast
(define-public (submit-forecast (generator-id uint) (forecast-period uint) (predicted-output uint) (weather-condition uint) (confidence-level uint))
  (begin
    (asserts! (> predicted-output u0) ERR_INVALID_FORECAST)
    (asserts! (<= confidence-level u100) ERR_INVALID_FORECAST)
    (asserts! (or (is-eq weather-condition SUNNY)
                  (is-eq weather-condition CLOUDY)
                  (is-eq weather-condition WINDY)
                  (is-eq weather-condition RAINY)) ERR_INVALID_FORECAST)

    (map-set forecasts
      { generator-id: generator-id, forecast-period: forecast-period }
      {
        predicted-output: predicted-output,
        weather-condition: weather-condition,
        confidence-level: confidence-level,
        created-at: block-height,
        forecaster: tx-sender
      }
    )

    ;; Update forecaster stats
    (match (map-get? historical-accuracy { forecaster: tx-sender })
      accuracy-data
      (map-set historical-accuracy
        { forecaster: tx-sender }
        (merge accuracy-data { total-forecasts: (+ (get total-forecasts accuracy-data) u1) })
      )
      (map-set historical-accuracy
        { forecaster: tx-sender }
        { total-forecasts: u1, accurate-forecasts: u0, accuracy-percentage: u0 }
      )
    )

    (ok true)
  )
)

;; Validate forecast accuracy (called after actual production is known)
(define-public (validate-forecast (generator-id uint) (forecast-period uint) (actual-output uint))
  (match (map-get? forecasts { generator-id: generator-id, forecast-period: forecast-period })
    forecast-data
    (let ((predicted (get predicted-output forecast-data))
          (forecaster (get forecaster forecast-data))
          (variance (if (>= actual-output predicted)
                       (- actual-output predicted)
                       (- predicted actual-output)))
          (accuracy-threshold (/ predicted u10))) ;; 10% threshold

      (if (<= variance accuracy-threshold)
        ;; Forecast was accurate
        (match (map-get? historical-accuracy { forecaster: forecaster })
          accuracy-data
          (let ((new-accurate (+ (get accurate-forecasts accuracy-data) u1))
                (total (get total-forecasts accuracy-data)))
            (map-set historical-accuracy
              { forecaster: forecaster }
              (merge accuracy-data {
                accurate-forecasts: new-accurate,
                accuracy-percentage: (/ (* new-accurate u100) total)
              })
            )
            (ok true)
          )
          (ok false)
        )
        (ok false)
      )
    )
    ERR_FORECAST_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-forecast (generator-id uint) (forecast-period uint))
  (map-get? forecasts { generator-id: generator-id, forecast-period: forecast-period })
)

(define-read-only (get-forecaster-accuracy (forecaster principal))
  (map-get? historical-accuracy { forecaster: forecaster })
)

(define-read-only (calculate-grid-forecast (generator-ids (list 10 uint)))
  (fold calculate-total-forecast generator-ids u0)
)

(define-private (calculate-total-forecast (generator-id uint) (total uint))
  (match (map-get? forecasts { generator-id: generator-id, forecast-period: block-height })
    forecast-data (+ total (get predicted-output forecast-data))
    total
  )
)
