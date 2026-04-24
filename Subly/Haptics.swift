import Foundation
import SwiftUI
import UIKit

enum HapticEvent: Equatable {
    case primaryTap
    case primaryLongPress
    case save
    case validationFail
    case scanStart
    case scanComplete
    case markCanceled
    case scheduleReminder
    case swipeThresholdCrossed
    case rowTap
    case sheetPresent
    case tabSwitch
    case destructiveConfirm
}

enum Haptics {
    static func play(_ event: HapticEvent) {
        guard !shouldSuppress() else { return }
        switch event {
        case .primaryTap:
            let g = UIImpactFeedbackGenerator(style: .soft)
            g.prepare()
            g.impactOccurred()
        case .primaryLongPress:
            let g = UIImpactFeedbackGenerator(style: .rigid)
            g.prepare()
            g.impactOccurred()
        case .save:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.success)
        case .validationFail:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.error)
        case .scanStart:
            let g = UISelectionFeedbackGenerator()
            g.prepare()
            g.selectionChanged()
        case .scanComplete:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.success)
        case .markCanceled:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.success)
        case .scheduleReminder:
            let g = UIImpactFeedbackGenerator(style: .soft)
            g.prepare()
            g.impactOccurred()
        case .swipeThresholdCrossed:
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            g.impactOccurred()
        case .rowTap:
            let g = UISelectionFeedbackGenerator()
            g.prepare()
            g.selectionChanged()
        case .sheetPresent:
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            g.impactOccurred()
        case .tabSwitch:
            let g = UISelectionFeedbackGenerator()
            g.prepare()
            g.selectionChanged()
        case .destructiveConfirm:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.warning)
        }
    }

    // Reduce Motion is the closest public proxy for a "less physical sensation" preference; iOS exposes no dedicated reduce-haptics flag, so we gate on it to respect that hidden user intent.
    private static func shouldSuppress() -> Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}

extension View {
    @ViewBuilder
    func haptic<T: Equatable>(_ event: HapticEvent, trigger: T) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(trigger: trigger) { _, _ in
                switch event {
                case .primaryTap: return .impact(flexibility: .soft)
                case .primaryLongPress: return .impact(flexibility: .rigid)
                case .save: return .success
                case .validationFail: return .error
                case .scanStart: return .selection
                case .scanComplete: return .success
                case .markCanceled: return .success
                case .scheduleReminder: return .impact(flexibility: .soft)
                case .swipeThresholdCrossed: return .impact(weight: .light)
                case .rowTap: return .selection
                case .sheetPresent: return .impact(flexibility: .soft)
                case .tabSwitch: return .selection
                case .destructiveConfirm: return .warning
                }
            }
        } else {
            self.onChange(of: trigger) { _, _ in
                Haptics.play(event)
            }
        }
    }
}
