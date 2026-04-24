import Foundation

/// An alert the app should schedule for a trial ending in the future.
/// `TrialEngine` produces these; the app layer persists them as `TrialAlert`
/// SwiftData rows and hands them to `NotificationEngine` for scheduling.
public struct PlannedTrialAlert: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case threeDaysBefore
        case dayBefore
        case dayOf
        case subscriptionDayBefore
    }

    public let trialID: UUID
    public let kind: Kind
    public let triggerDate: Date

    public init(trialID: UUID, kind: Kind, triggerDate: Date) {
        self.trialID = trialID
        self.kind = kind
        self.triggerDate = triggerDate
    }
}

public enum TrialEngine {
    /// Plans the 3-day, 1-day, and day-of alerts for a given trial charge date.
    ///
    /// - 3-day alert fires at 9:00 local time, 3 days before `chargeDate`.
    /// - 1-day alert fires at 9:00 local time, 1 day before `chargeDate`.
    /// - Day-of alert fires at 9:00 local time on the day the trial ends.
    ///
    /// Alerts whose `triggerDate` is not in the future relative to `now` are
    /// dropped — we don't schedule notifications for times that already passed.
    public static func plan(
        trialID: UUID,
        chargeDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedTrialAlert] {
        let morningOfEnd = alertTime(on: chargeDate, calendar: calendar)
        guard let threeDaysBefore = calendar.date(byAdding: .day, value: -3, to: morningOfEnd),
              let dayBefore = calendar.date(byAdding: .day, value: -1, to: morningOfEnd) else {
            return []
        }

        let candidates: [PlannedTrialAlert] = [
            .init(trialID: trialID, kind: .threeDaysBefore, triggerDate: threeDaysBefore),
            .init(trialID: trialID, kind: .dayBefore, triggerDate: dayBefore),
            .init(trialID: trialID, kind: .dayOf, triggerDate: morningOfEnd),
        ]

        return candidates.filter { $0.triggerDate > now }
    }

    /// Plans the default 1-day-before alert for a subscription renewal.
    /// Subscriptions are expected charges, so we use a single heads-up alert
    /// by default (customizable via per-entry notificationOffset).
    public static func planSubscription(
        entryID: UUID,
        chargeDate: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PlannedTrialAlert] {
        let morningOfCharge = alertTime(on: chargeDate, calendar: calendar)
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: morningOfCharge) else {
            return []
        }
        let candidate = PlannedTrialAlert(
            trialID: entryID,
            kind: .subscriptionDayBefore,
            triggerDate: dayBefore
        )
        return candidate.triggerDate > now ? [candidate] : []
    }

    /// 9:00 local time on the day containing `date`.
    private static func alertTime(on date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        var shifted = components
        shifted.hour = 9
        shifted.minute = 0
        shifted.second = 0
        return calendar.date(from: shifted) ?? date
    }
}
