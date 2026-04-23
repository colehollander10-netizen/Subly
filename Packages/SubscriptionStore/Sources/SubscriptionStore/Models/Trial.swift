import Foundation
import SwiftData

/// A free trial the user has captured — via screenshot share, pasted email,
/// or typed manually. Trials are always user-initiated; there is no automatic
/// email ingestion.
@Model
public final class Trial {
    @Attribute(.unique) public var id: UUID
    public var serviceName: String
    /// Optional hint for logo lookup. Empty string when unknown.
    public var senderDomain: String
    public var trialEndDate: Date
    public var chargeAmount: Decimal?
    public var detectedAt: Date
    public var userDismissed: Bool
    /// Length of the trial in whole days, when known. 7, 14, 30, 90, 365 are common.
    public var trialLengthDays: Int? = nil

    public init(
        id: UUID = UUID(),
        serviceName: String,
        senderDomain: String = "",
        trialEndDate: Date,
        chargeAmount: Decimal?,
        detectedAt: Date = Date(),
        userDismissed: Bool = false,
        trialLengthDays: Int? = nil
    ) {
        self.id = id
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.trialEndDate = trialEndDate
        self.chargeAmount = chargeAmount
        self.detectedAt = detectedAt
        self.userDismissed = userDismissed
        self.trialLengthDays = trialLengthDays
    }
}
