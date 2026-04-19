import Foundation
import SwiftData

public enum ScanStatus: String, Codable, Sendable {
    case idle, scanning
}

@Model
public final class EmailScanState {
    public var lastScannedAt: Date
    public var nextPageToken: String?
    public var status: ScanStatus
    public var errorMessage: String?

    public init(
        lastScannedAt: Date,
        nextPageToken: String?,
        status: ScanStatus,
        errorMessage: String?
    ) {
        self.lastScannedAt = lastScannedAt
        self.nextPageToken = nextPageToken
        self.status = status
        self.errorMessage = errorMessage
    }
}
