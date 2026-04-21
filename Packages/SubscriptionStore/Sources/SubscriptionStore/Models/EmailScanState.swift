import Foundation
import SwiftData

public enum ScanStatus: String, Codable, Sendable {
    case idle, scanning
}

/// Global scan state. Tracks the last time any scan finished, what happened,
/// and whether one is currently running. Not per-account — the UI only ever
/// shows one aggregate "Last scanned X minutes ago" line.
@Model
public final class EmailScanState {
    public var lastScannedAt: Date
    public var status: ScanStatus
    public var errorMessage: String?

    public init(
        lastScannedAt: Date,
        status: ScanStatus,
        errorMessage: String?
    ) {
        self.lastScannedAt = lastScannedAt
        self.status = status
        self.errorMessage = errorMessage
    }
}
