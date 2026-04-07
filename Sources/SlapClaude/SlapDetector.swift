import Foundation

enum Sensitivity: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2

    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    // RMS amplitude spike above baseline (0.0–1.0 normalized audio).
    var audioThreshold: Float {
        switch self {
        case .low:    return 0.35
        case .medium: return 0.18
        case .high:   return 0.08
        }
    }

    // g-force spike above EMA baseline (~1g at rest).
    var accelThreshold: Double {
        switch self {
        case .low:    return 3.0
        case .medium: return 1.5
        case .high:   return 0.8
        }
    }
}
