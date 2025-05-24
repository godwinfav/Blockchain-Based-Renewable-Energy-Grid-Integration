import { describe, it, expect, beforeEach } from "vitest"

// Mock Clarity contract functions for testing
const mockContract = {
  currentLoad: 0,
  currentGeneration: 0,
  gridFrequency: 5000, // 50.00 Hz
  gridStatus: 1, // STABLE
  lastUpdate: 0,
  stabilityEvents: new Map(),
  nextEventId: 1,
  contractOwner: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
}

// Grid status constants
const STABLE = 1
const WARNING = 2
const CRITICAL = 3
const EMERGENCY = 4

// Frequency thresholds
const MIN_FREQUENCY = 4950 // 49.50 Hz
const MAX_FREQUENCY = 5050 // 50.50 Hz
const CRITICAL_LOW = 4900 // 49.00 Hz
const CRITICAL_HIGH = 5100 // 51.00 Hz

// Mock contract functions
function updateGridState(load, generation, frequency, sender) {
  if (load <= 0) return { error: "ERR_INVALID_PARAMETERS" }
  if (generation <= 0) return { error: "ERR_INVALID_PARAMETERS" }
  if (frequency <= 4000) return { error: "ERR_INVALID_PARAMETERS" }
  if (frequency >= 6000) return { error: "ERR_INVALID_PARAMETERS" }
  
  mockContract.currentLoad = load
  mockContract.currentGeneration = generation
  mockContract.gridFrequency = frequency
  mockContract.lastUpdate = 100
  
  const newStatus = calculateGridStatus(load, generation, frequency)
  mockContract.gridStatus = newStatus
  
  if (newStatus !== STABLE) {
    logStabilityEvent(newStatus, load, generation, frequency)
  }
  
  return { success: true }
}

function calculateGridStatus(load, generation, frequency) {
  const loadGenerationRatio = generation > 0 ? Math.floor((load * 100) / generation) : 200
  const frequencyOk = frequency >= MIN_FREQUENCY && frequency <= MAX_FREQUENCY
  
  if (frequency <= CRITICAL_LOW || frequency >= CRITICAL_HIGH) {
    return EMERGENCY
  }
  
  if (!frequencyOk || loadGenerationRatio > 120 || loadGenerationRatio < 80) {
    return CRITICAL
  }
  
  if (loadGenerationRatio > 110 || loadGenerationRatio < 90) {
    return WARNING
  }
  
  return STABLE
}

function logStabilityEvent(eventType, load, generation, frequency) {
  const eventId = mockContract.nextEventId
  const action = getRecommendedAction(eventType, load, generation, frequency)
  
  mockContract.stabilityEvents.set(eventId, {
    timestamp: 100,
    eventType,
    load,
    generation,
    frequency,
    actionTaken: action,
  })
  
  mockContract.nextEventId++
  return { success: true }
}

function getRecommendedAction(status, load, generation, frequency) {
  if (status === EMERGENCY) return "EMERGENCY_SHUTDOWN"
  if (status === CRITICAL) {
    return load > generation ? "INCREASE_GENERATION" : "REDUCE_LOAD"
  }
  if (status === WARNING) return "MONITOR_CLOSELY"
  return "NO_ACTION"
}

function emergencyShutdown(sender) {
  if (sender !== mockContract.contractOwner) return { error: "ERR_UNAUTHORIZED" }
  
  mockContract.gridStatus = EMERGENCY
  logStabilityEvent(EMERGENCY, mockContract.currentLoad, mockContract.currentGeneration, mockContract.gridFrequency)
  return { success: true }
}

function getGridStatus() {
  return {
    load: mockContract.currentLoad,
    generation: mockContract.currentGeneration,
    frequency: mockContract.gridFrequency,
    status: mockContract.gridStatus,
    lastUpdate: mockContract.lastUpdate,
  }
}

function getStabilityEvent(eventId) {
  return mockContract.stabilityEvents.get(eventId) || null
}

function isGridStable() {
  return mockContract.gridStatus === STABLE
}

function getLoadGenerationBalance() {
  const load = mockContract.currentLoad
  const generation = mockContract.currentGeneration
  return generation > 0 ? Math.floor((load * 100) / generation) : 0
}

describe("Grid Stability Contract", () => {
  beforeEach(() => {
    // Reset mock contract state
    mockContract.currentLoad = 0
    mockContract.currentGeneration = 0
    mockContract.gridFrequency = 5000
    mockContract.gridStatus = STABLE
    mockContract.lastUpdate = 0
    mockContract.stabilityEvents.clear()
    mockContract.nextEventId = 1
  })
  
  describe("Grid State Updates", () => {
    it("should update grid state with valid parameters", () => {
      const result = updateGridState(1000, 1050, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      expect(result.success).toBe(true)
      
      const status = getGridStatus()
      expect(status.load).toBe(1000)
      expect(status.generation).toBe(1050)
      expect(status.frequency).toBe(5000)
      expect(status.status).toBe(STABLE)
      expect(status.lastUpdate).toBe(100)
    })
    
    it("should reject invalid load", () => {
      const result = updateGridState(0, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(result.error).toBe("ERR_INVALID_PARAMETERS")
    })
    
    it("should reject invalid generation", () => {
      const result = updateGridState(1000, 0, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(result.error).toBe("ERR_INVALID_PARAMETERS")
    })
    
    it("should reject frequency too low", () => {
      const result = updateGridState(1000, 1000, 3000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(result.error).toBe("ERR_INVALID_PARAMETERS")
    })
    
    it("should reject frequency too high", () => {
      const result = updateGridState(1000, 1000, 7000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(result.error).toBe("ERR_INVALID_PARAMETERS")
    })
  })
  
  describe("Grid Status Calculation", () => {
    it("should maintain stable status with balanced load and frequency", () => {
      updateGridState(1000, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const status = getGridStatus()
      expect(status.status).toBe(STABLE)
      expect(isGridStable()).toBe(true)
    })
    
    it("should set critical status with high imbalance", () => {
      updateGridState(1300, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM") // 130% ratio
      
      const status = getGridStatus()
      expect(status.status).toBe(CRITICAL)
      expect(isGridStable()).toBe(false)
    })
    
    it("should set emergency status with critical frequency", () => {
      updateGridState(1000, 1000, CRITICAL_LOW, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const status = getGridStatus()
      expect(status.status).toBe(EMERGENCY)
      expect(isGridStable()).toBe(false)
    })
    
    it("should set critical status with frequency outside normal range", () => {
      updateGridState(1000, 1000, 4940, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM") // Below MIN_FREQUENCY
      
      const status = getGridStatus()
      expect(status.status).toBe(CRITICAL)
    })
  })
  
  describe("Load Generation Balance", () => {
    it("should calculate correct balance ratio", () => {
      updateGridState(1000, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const balance = getLoadGenerationBalance()
      expect(balance).toBe(100) // 100% balance
    })
    
    it("should handle excess generation", () => {
      updateGridState(800, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const balance = getLoadGenerationBalance()
      expect(balance).toBe(80) // 80% - excess generation
    })
    
    it("should handle excess load", () => {
      updateGridState(1200, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const balance = getLoadGenerationBalance()
      expect(balance).toBe(120) // 120% - excess load
    })
    
    it("should handle zero generation", () => {
      mockContract.currentLoad = 1000
      mockContract.currentGeneration = 0
      
      const balance = getLoadGenerationBalance()
      expect(balance).toBe(0)
    })
  })
  
  describe("Stability Event Logging", () => {
    
    it("should log critical events with appropriate actions", () => {
      updateGridState(1300, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const event = getStabilityEvent(1)
      expect(event).toBeTruthy()
      expect(event.eventType).toBe(CRITICAL)
      expect(event.actionTaken).toBe("INCREASE_GENERATION")
    })
    
    it("should log emergency events", () => {
      updateGridState(1000, 1000, CRITICAL_LOW, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const event = getStabilityEvent(1)
      expect(event).toBeTruthy()
      expect(event.eventType).toBe(EMERGENCY)
      expect(event.actionTaken).toBe("EMERGENCY_SHUTDOWN")
    })
    
    it("should not log stable events", () => {
      updateGridState(1000, 1000, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      
      const event = getStabilityEvent(1)
      expect(event).toBeNull()
    })
    
    it("should recommend reduce load for excess load", () => {
      updateGridState(800, 1000, 4940, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM") // Critical due to frequency
      
      const event = getStabilityEvent(1)
      expect(event.actionTaken).toBe("REDUCE_LOAD") // Load < generation
    })
  })
  
  describe("Emergency Shutdown", () => {
    it("should allow emergency shutdown by contract owner", () => {
      const result = emergencyShutdown(mockContract.contractOwner)
      
      expect(result.success).toBe(true)
      expect(mockContract.gridStatus).toBe(EMERGENCY)
      
      const event = getStabilityEvent(1)
      expect(event).toBeTruthy()
      expect(event.eventType).toBe(EMERGENCY)
    })
    
    it("should reject emergency shutdown by non-owner", () => {
      const result = emergencyShutdown("ST2PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(result.error).toBe("ERR_UNAUTHORIZED")
    })
  })
  
  describe("Data Retrieval", () => {
    beforeEach(() => {
      updateGridState(1200, 1000, 4960, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
    })
    
    
    
    it("should return null for non-existent events", () => {
      const event = getStabilityEvent(999)
      expect(event).toBeNull()
    })
  })
  
  describe("Frequency Thresholds", () => {
    it("should handle frequency at exact thresholds", () => {
      // Test MIN_FREQUENCY boundary
      updateGridState(1000, 1000, MIN_FREQUENCY, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(STABLE)
      
      updateGridState(1000, 1000, MIN_FREQUENCY - 1, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(CRITICAL)
      
      // Test MAX_FREQUENCY boundary
      updateGridState(1000, 1000, MAX_FREQUENCY, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(STABLE)
      
      updateGridState(1000, 1000, MAX_FREQUENCY + 1, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(CRITICAL)
    })
    
    it("should handle critical frequency thresholds", () => {
      // Test CRITICAL_LOW boundary
      updateGridState(1000, 1000, CRITICAL_LOW, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(EMERGENCY)
      
      // Test CRITICAL_HIGH boundary
      updateGridState(1000, 1000, CRITICAL_HIGH, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(EMERGENCY)
    })
  })
  
  describe("Edge Cases", () => {
    it("should handle very large load and generation values", () => {
      const result = updateGridState(999999, 999999, 5000, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(result.success).toBe(true)
      
      const status = getGridStatus()
      expect(status.load).toBe(999999)
      expect(status.generation).toBe(999999)
      expect(status.status).toBe(STABLE)
    })
    
    it("should handle frequency at exact emergency thresholds", () => {
      updateGridState(1000, 1000, CRITICAL_LOW - 1, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(EMERGENCY)
      
      updateGridState(1000, 1000, CRITICAL_HIGH + 1, "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM")
      expect(getGridStatus().status).toBe(EMERGENCY)
    })
  })
})
