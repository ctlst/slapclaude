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
    // A moderate palm-slap on a MacBook typically produces 0.15–0.4 RMS.
    var audioThreshold: Float {
        switch self {
        case .low:    return 0.35  // Firm slap only
        case .medium: return 0.18  // Normal slap
        case .high:   return 0.08  // Light tap
        }
    }
}
