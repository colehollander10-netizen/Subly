import Foundation
import NotificationEngine
import SubscriptionStore
import SwiftData
import TrialEngine

/// Plans and schedules local trial-end notifications for every active
/// (non-dismissed, future-ending) `Trial`. Call `replanAll()` on app launch
/// and after every scan.
///
/// Existing *undelivered* TrialAlert rows for a trial are deleted and
/// replaced on every call — ensuring triggerDates stay fresh if a re-scan
/// updates the `trialEndDate`. Delivered alerts are kept as history.
actor TrialAlertCoordinator {
    private let modelContainer: ModelContainer
    private let notificationEngine: NotificationEngine

    init(modelContainer: ModelContainer, notificationEngine: NotificationEngine) {
        self.modelContainer = modelContainer
        self.notificationEngine = notificationEngine
    }

    /// Replans all TrialAlerts and reschedules every pending notification.
    /// Safe to call on every launch — idempotent.
    func replanAll(now: Date = Date()) async {
        let context = ModelContext(modelContainer)

        let trials = fetchActiveTrials(context: context, now: now)

        for trial in trials {
            deleteUndeliveredAlerts(for: trial.id, context: context)

            let planned = TrialEngine.plan(
                trialID: trial.id,
                trialEndDate: trial.trialEndDate,
                now: now
            )

            for p in planned {
                let alert = TrialAlert(
                    id: UUID(),
                    trialID: trial.id,
                    triggerDate: p.triggerDate,
                    alertType: alertType(for: p.kind),
                    delivered: false
                )
                context.insert(alert)
            }
        }

        try? context.save()

        await scheduleNotifications(context: context, now: now)
    }

    // MARK: - Private helpers

    private func fetchActiveTrials(context: ModelContext, now: Date) -> [Trial] {
        let descriptor = FetchDescriptor<Trial>(
            predicate: #Predicate { !$0.userDismissed }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0.trialEndDate > now }
    }

    private func deleteUndeliveredAlerts(for trialID: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<TrialAlert>(
            predicate: #Predicate {
                $0.trialID == trialID && !$0.delivered
            }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for alert in existing {
            context.delete(alert)
        }
    }

    private func scheduleNotifications(context: ModelContext, now: Date) async {
        let descriptor = FetchDescriptor<TrialAlert>(
            predicate: #Predicate { !$0.delivered }
        )
        let pending = (try? context.fetch(descriptor)) ?? []

        let trialIDs = Set(pending.map(\.trialID))
        var trialMap: [UUID: Trial] = [:]
        for id in trialIDs {
            let d = FetchDescriptor<Trial>(
                predicate: #Predicate { $0.id == id }
            )
            if let trial = (try? context.fetch(d))?.first {
                trialMap[id] = trial
            }
        }

        let scheduled: [ScheduledAlert] = pending.compactMap { alert in
            guard let trial = trialMap[alert.trialID] else { return nil }
            let (title, body) = notificationCopy(for: alert.alertType, trial: trial)
            return ScheduledAlert(
                id: alert.id.uuidString,
                title: title,
                body: body,
                triggerDate: alert.triggerDate
            )
        }

        await notificationEngine.scheduleAll(scheduled, now: now)
    }

    private func alertType(for kind: PlannedTrialAlert.Kind) -> AlertType {
        switch kind {
        case .threeDaysBefore: return .threeDaysBefore
        case .dayOf:           return .dayOf
        }
    }

    /// Builds notification copy using the service name and charge amount.
    private func notificationCopy(
        for alertType: AlertType,
        trial: Trial
    ) -> (title: String, body: String) {
        let name = trial.serviceName
        let amountString = trial.chargeAmount.map { "$\($0)" }

        switch alertType {
        case .threeDaysBefore:
            let title = "\(name) trial ends in 3 days"
            let body = amountString.map {
                "You'll be charged \($0) unless you cancel before your trial ends."
            } ?? "Cancel before your trial ends to avoid being charged."
            return (title, body)

        case .dayOf:
            let title = "\(name) trial ends today"
            let body = amountString.map {
                "Your \(name) trial ends today. Cancel now to avoid the \($0) charge."
            } ?? "Your \(name) trial ends today. Cancel now to avoid being charged."
            return (title, body)

        case .dayBefore:
            let title = "\(name) trial ends tomorrow"
            let body = amountString.map {
                "You'll be charged \($0) tomorrow unless you cancel today."
            } ?? "Cancel today to avoid being charged when your trial ends tomorrow."
            return (title, body)

        case .custom(let days):
            let dayWord = days == 1 ? "day" : "days"
            let title = "\(name) trial ends in \(days) \(dayWord)"
            let body = amountString.map {
                "You'll be charged \($0) in \(days) \(dayWord)."
            } ?? "Cancel before your trial ends to avoid being charged."
            return (title, body)
        }
    }
}
