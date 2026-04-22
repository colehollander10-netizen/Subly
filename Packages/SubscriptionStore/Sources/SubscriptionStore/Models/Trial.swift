import Foundation
import SwiftData

/// A Gmail account the user has connected. One per Google account (work,
/// personal, etc.). The `id` is the Google-assigned userID that matches
/// EmailEngine's Keychain entry, so the app layer can cross-reference.
@Model
public final class ConnectedAccount {
    @Attribute(.unique) public var id: String
    public var email: String
    public var addedAt: Date
    public var lastScannedAt: Date?
    /// True when Google rejected our refresh token (revoked, Workspace policy
    /// change, etc.). The account stays in the UI but scans will no-op until
    /// the user reconnects it in Settings.
    public var needsReconnect: Bool = false

    public init(
        id: String,
        email: String,
        addedAt: Date = Date(),
        lastScannedAt: Date? = nil,
        needsReconnect: Bool = false
    ) {
        self.id = id
        self.email = email
        self.addedAt = addedAt
        self.lastScannedAt = lastScannedAt
        self.needsReconnect = needsReconnect
    }
}

/// A free trial the user is currently in or has added manually.
///
/// Auto-detected trials have `sourceEmailID` set. User-added trials have
/// it nil — they're tracked the same way, just without an email origin.
@Model
public final class Trial {
    @Attribute(.unique) public var id: UUID
    /// Owner account's Google userID (ConnectedAccount.id). Empty string for
    /// user-added trials that didn't come from any specific inbox.
    public var accountID: String
    public var serviceName: String
    public var senderDomain: String
    public var trialEndDate: Date
    public var chargeAmount: Decimal?
    public var detectedAt: Date
    /// Gmail message ID. Nil for user-added trials.
    public var sourceEmailID: String?
    public var userDismissed: Bool
    /// True when the user entered the trial manually (vs. parsed from email).
    public var isManual: Bool
    /// True when detected from a welcome-email with no charge amount — needs
    /// user confirmation before becoming a full trial.
    public var isLead: Bool
    /// Length of the trial in whole days, when known. Nil means we couldn't
    /// extract or infer it. 7, 14, 30, 90, 365 are the common values.
    public var trialLengthDays: Int? = nil

    public init(
        id: UUID = UUID(),
        accountID: String,
        serviceName: String,
        senderDomain: String,
        trialEndDate: Date,
        chargeAmount: Decimal?,
        detectedAt: Date = Date(),
        sourceEmailID: String?,
        userDismissed: Bool = false,
        isManual: Bool = false,
        isLead: Bool = false,
        trialLengthDays: Int? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.serviceName = serviceName
        self.senderDomain = senderDomain
        self.trialEndDate = trialEndDate
        self.chargeAmount = chargeAmount
        self.detectedAt = detectedAt
        self.sourceEmailID = sourceEmailID
        self.userDismissed = userDismissed
        self.isManual = isManual
        self.isLead = isLead
        self.trialLengthDays = trialLengthDays
    }
}
