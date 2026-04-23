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

        let trials = fetchSchedulableTrials(context: context, now: now)
        let trialMap = fetchTrialMap(context: context)
        let schedulableTrialIDs = Set(trials.map(\.id))

        pruneUndeliveredAlerts(
            context: context,
            trialMap: trialMap,
            schedulableTrialIDs: schedulableTrialIDs,
            now: now
        )

        for trial in trials {
            deleteUndeliveredPlannedAlerts(for: trial.id, context: context)

            let planned = TrialEngine.plan(
                trialID: trial.id,
                trialEndDate: trial.chargeDate,
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

        await scheduleNotifications(
            context: context,
            trialMap: fetchTrialMap(context: context),
            schedulableTrialIDs: schedulableTrialIDs,
            now: now
        )
    }

    // MARK: - Private helpers

    private func fetchSchedulableTrials(context: ModelContext, now: Date) -> [Trial] {
        let descriptor = FetchDescriptor<Trial>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { !$0.userDismissed && $0.chargeDate > now }
    }

    private func fetchTrialMap(context: ModelContext) -> [UUID: Trial] {
        let descriptor = FetchDescriptor<Trial>()
        let trials = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: trials.map { ($0.id, $0) })
    }

    private func deleteUndeliveredPlannedAlerts(for trialID: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<TrialAlert>(
            predicate: #Predicate {
                $0.trialID == trialID && !$0.delivered
            }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for alert in existing {
            if replansOnScan(alert.alertType) {
                context.delete(alert)
            }
        }
    }

    private func pruneUndeliveredAlerts(
        context: ModelContext,
        trialMap: [UUID: Trial],
        schedulableTrialIDs: Set<UUID>,
        now: Date
    ) {
        let descriptor = FetchDescriptor<TrialAlert>(
            predicate: #Predicate { !$0.delivered }
        )
        let alerts = (try? context.fetch(descriptor)) ?? []

        for alert in alerts {
            guard let trial = trialMap[alert.trialID] else {
                context.delete(alert)
                continue
            }

            if trial.userDismissed || trial.chargeDate <= now {
                context.delete(alert)
                continue
            }

            if replansOnScan(alert.alertType) && !schedulableTrialIDs.contains(trial.id) {
                context.delete(alert)
            }
        }
    }

    private func scheduleNotifications(
        context: ModelContext,
        trialMap: [UUID: Trial],
        schedulableTrialIDs: Set<UUID>,
        now: Date
    ) async {
        let descriptor = FetchDescriptor<TrialAlert>(
            predicate: #Predicate { !$0.delivered }
        )
        let pending = (try? context.fetch(descriptor)) ?? []

        let scheduled: [ScheduledAlert] = pending.compactMap { alert in
            guard let trial = trialMap[alert.trialID] else { return nil }
            guard !trial.userDismissed, trial.chargeDate > now else { return nil }
            guard schedulableTrialIDs.contains(trial.id) || alert.alertType == .followUp else { return nil }
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
        case .dayBefore:       return .dayBefore
        case .dayOf:           return .dayOf
        }
    }

    private func replansOnScan(_ alertType: AlertType) -> Bool {
        switch alertType {
        case .threeDaysBefore, .dayOf, .dayBefore, .custom:
            return true
        case .followUp:
            return false
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
            let title = "\(name) charges in 3 days"
            let body = amountString.map {
                "Cancel before renewal day to avoid the \($0) charge."
            } ?? "Cancel before renewal day to avoid being charged."
            return (title, body)

        case .dayOf:
            let title = "\(name) charges today"
            let body = amountString.map {
                "Last chance: cancel now to avoid the \($0) charge."
            } ?? "Last chance: cancel now to avoid being charged."
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

        case .followUp:
            let title = "Still need to cancel \(name)?"
            let body = amountString.map {
                "Open Subly for the cancel steps before the \($0) charge lands."
            } ?? "Open Subly for the cancel steps before the charge lands."
            return (title, body)
        }
    }
}
