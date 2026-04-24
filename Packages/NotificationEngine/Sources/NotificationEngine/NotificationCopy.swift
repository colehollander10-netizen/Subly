import Foundation

public struct RenderedCopy: Sendable, Equatable {
    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }
}

public enum NotificationCopy {
    public enum TrialKind: Sendable {
        case threeDaysBefore
        case dayBefore
        case dayOf
    }

    public static func trial(
        kind: TrialKind,
        serviceName: String,
        chargeAmount: Decimal?,
        chargeDate: Date
    ) -> RenderedCopy {
        let amount = formatAmount(chargeAmount)
        let dateStr = shortDate(chargeDate)
        switch kind {
        case .threeDaysBefore:
            return RenderedCopy(
                title: "Your \(serviceName) trial ends in 3 days",
                body: "\(amount) charges on \(dateStr)"
            )
        case .dayBefore:
            return RenderedCopy(
                title: "Your \(serviceName) trial ends tomorrow",
                body: "\(amount) charges on \(dateStr)"
            )
        case .dayOf:
            return RenderedCopy(
                title: "Your \(serviceName) trial charges today",
                body: amount
            )
        }
    }

    public static func subscription(
        serviceName: String,
        chargeAmount: Decimal?,
        chargeDate: Date
    ) -> RenderedCopy {
        let amount = formatAmount(chargeAmount)
        _ = chargeDate
        return RenderedCopy(
            title: "\(serviceName) renews tomorrow",
            body: amount
        )
    }

    public static func subscription(
        serviceName: String,
        chargeAmount: Decimal?
    ) -> RenderedCopy {
        subscription(serviceName: serviceName, chargeAmount: chargeAmount, chargeDate: Date())
    }

    private static func formatAmount(_ amount: Decimal?) -> String {
        guard let amount else { return "" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: amount as NSDecimalNumber) ?? ""
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
