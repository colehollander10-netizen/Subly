import Foundation
import Testing
@testable import TrialParsingCore

struct TrialParserTests {
    private let referenceNow = ISO8601DateFormatter().date(from: "2026-03-05T12:00:00Z")!

    // MARK: - Clean plaintext (best case: pasted email or share-email source)

    @Test
    func cleanPlaintext_allFixturesClassifyAsExpected() {
        for fixture in TrialFixture.allCases {
            let classification = TrialParser.classifyText(
                fixture.asSharedEmailText,
                now: referenceNow,
                source: .sharedEmail
            )
            #expect(classification.confidence == fixture.expectedConfidence,
                    "\(fixture): expected \(fixture.expectedConfidence), got \(classification.confidence)")
            #expect(classification.event == fixture.expectedEvent,
                    "\(fixture): expected \(fixture.expectedEvent) event")
            #expect(classification.willAutoCharge == fixture.expectedWillAutoCharge,
                    "\(fixture): willAutoCharge mismatch")
        }
    }

    @Test
    func cleanPlaintext_merchantNamesExtract() {
        let expectations: [(TrialFixture, String)] = [
            (.anthropicClaude, "Claude Pro"),
            (.googleCloud, "Google Cloud"),
            (.granola, "Granola Business"),
            (.loom, "Loom"),
            (.zapier, "Zapier"),
        ]
        for (fixture, expectedName) in expectations {
            let classification = TrialParser.classifyText(
                fixture.asSharedEmailText,
                now: referenceNow,
                source: .sharedEmail
            )
            #expect(classification.serviceName == expectedName,
                    "\(fixture): expected name '\(expectedName)', got '\(classification.serviceName)'")
        }
    }

    // MARK: - Screenshot (no subject/from)

    @Test
    func screenshotSource_retainsHighOrMediumConfidence() {
        for fixture in TrialFixture.allCases {
            let classification = TrialParser.classifyText(
                fixture.asScreenshotText,
                now: referenceNow,
                source: .screenshot
            )
            #expect(classification.confidence != .low,
                    "\(fixture) via screenshot dropped to .low (rejection: \(classification.rejectionReason?.rawValue ?? "none"))")
        }
    }

    // MARK: - Marketing gate must survive all degradation levels

    @Test
    func marketingOffer_rejectedAcrossDegradation() {
        let promo = """
        Just for you: 2 months of Uber One free trial
        Claim your free trial today.
        Limited time offer.
        """
        for level in OCRLevel.allCases {
            let degraded = ocrDegrade(promo, level: level)
            let classification = TrialParser.classifyText(
                degraded,
                now: referenceNow,
                source: .screenshot
            )
            #expect(classification.confidence == .low,
                    "Marketing promo at \(level) should be low, got \(classification.confidence)")
        }
    }

    // MARK: - OCR degradation survival (soft target — measures, doesn't assert tight bounds)

    @Test
    func ocrLight_retainsAllFixtures() {
        let count = countHighOrMedium(level: .light)
        #expect(count >= 6, "OCR light expected 6/6 high-or-medium, got \(count)/6")
    }

    @Test
    func ocrMedium_retainsMostFixtures() {
        let count = countHighOrMedium(level: .medium)
        #expect(count >= 5, "OCR medium expected at least 5/6, got \(count)/6")
    }

    @Test
    func ocrHeavy_retainsSignalOnMost() {
        let detections = TrialFixture.allCases.map { fixture -> Bool in
            let degraded = ocrDegrade(fixture.asScreenshotText, level: .heavy)
            let classification = TrialParser.classifyText(
                degraded,
                now: referenceNow,
                source: .screenshot
            )
            return classification.signals.isTrialStart
        }
        let detected = detections.filter { $0 }.count
        #expect(detected >= 4,
                "OCR heavy expected at least 4/6 trial-signal detections, got \(detected)/6")
    }

    // MARK: - Holdout: emails not used to tune the parser

    @Test
    func holdout_netflixClassifiesHigh() {
        let text = """
        Welcome to Netflix
        Your 30-day free trial has started.
        Your trial ends on May 22, 2026.
        Payment method: Visa ending in 4321.
        After your trial, you will be charged $15.49 monthly.
        """
        let classification = TrialParser.classifyText(text, now: referenceNow, source: .sharedEmail)
        #expect(classification.confidence == .high)
        #expect(classification.chargeAmount == Decimal(string: "15.49"))
        #expect(classification.trialLengthDays == 30)
        #expect(dateComponents(for: classification.trialEndDate) == DateComponents(year: 2026, month: 5, day: 22))
    }

    @Test
    func holdout_notionClassifiesHigh() {
        let text = """
        Your Notion Plus trial is here
        Thanks for starting your free trial with Notion.
        Your 14 day free trial begins today and ends on May 6, 2026.
        We'll charge the card on file $10.00 when your trial ends.
        Cancel anytime before the trial ends to avoid being charged.
        """
        let classification = TrialParser.classifyText(text, now: referenceNow, source: .sharedEmail)
        #expect(classification.confidence == .high)
        #expect(classification.chargeAmount == Decimal(string: "10"))
        #expect(classification.trialLengthDays == 14)
        #expect(dateComponents(for: classification.trialEndDate) == DateComponents(year: 2026, month: 5, day: 6))
    }

    @Test
    func emptyInput_returnsNoBody() {
        let classification = TrialParser.classifyText("", now: referenceNow, source: .pastedText)
        #expect(classification.confidence == .low)
        #expect(classification.rejectionReason == .noBody)
    }

    // MARK: - Helpers

    private func countHighOrMedium(level: OCRLevel) -> Int {
        TrialFixture.allCases.filter { fixture in
            let degraded = ocrDegrade(fixture.asScreenshotText, level: level)
            let classification = TrialParser.classifyText(
                degraded,
                now: referenceNow,
                source: .screenshot
            )
            return classification.confidence != .low
        }.count
    }

    private func dateComponents(for date: Date?) -> DateComponents? {
        guard let date else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Calendar.current.timeZone
        return calendar.dateComponents([.year, .month, .day], from: date)
    }
}

// MARK: - Fixtures

private enum TrialFixture: CaseIterable {
    case microsoft365
    case anthropicClaude
    case googleCloud
    case granola
    case loom
    case zapier

    var asSharedEmailText: String {
        switch self {
        case .microsoft365:
            return """
            Your purchase of Microsoft 365 Personal has been processed

            Your purchase of Microsoft 365 Personal has been processed
            Thanks for subscribing to Microsoft 365 Personal. We're happy you're here.

            We've charged USD 0.00 to PayPal.
            Starting Monday, October 19, 2026, your payment of USD 4.99 plus applicable taxes will be charged to PayPal automatically every 1 month.
            Renewal Date: October 19, 2026
            Order Number: 6924165080
            Plan Price: USD 4.99 plus applicable taxes/1 month
            """
        case .anthropicClaude:
            return """
            Your Claude Pro trial has started

            Your 7 day free trial has started.
            Trial ends on April 11, 2026.
            Receipt number 99123.
            Your card ending in 4242 will be charged $20.00 automatically after your trial ends.
            """
        case .googleCloud:
            return """
            Welcome to your Google Cloud free trial

            Welcome to your Google Cloud free trial.
            Your 30 day free trial ends on April 30, 2026.
            Payment method Visa ending in 1111.
            After your trial ends, you will be charged $300.00 automatically.
            Invoice ID 1234.
            """
        case .granola:
            return """
            Your Granola Business free trial has started

            Your 14 day free trial starts now.
            The trial ends automatically when it expires, no credit card needed.
            """
        case .loom:
            return """
            Your Loom free trial starts now

            Your 14 day free trial starts now.
            No payment info required.
            Trial ends on March 15, 2026.
            """
        case .zapier:
            return """
            Your Zapier free trial has started

            Your free trial has started.
            Trial ends on March 20, 2026.
            No credit card needed to continue.
            """
        }
    }

    var asScreenshotText: String {
        switch self {
        case .microsoft365:
            return """
            Your purchase of Microsoft 365 Personal has been processed
            Thanks for subscribing to Microsoft 365 Personal. We're happy you're here.
            We've charged USD 0.00 to PayPal.
            Starting Monday, October 19, 2026, your payment of USD 4.99 plus applicable taxes will be charged to PayPal automatically every 1 month.
            Renewal Date: October 19, 2026
            Order Number: 6924165080
            Plan Price: USD 4.99 plus applicable taxes/1 month
            """
        case .anthropicClaude:
            return """
            Your Claude Pro trial has started
            Your 7 day free trial has started.
            Trial ends on April 11, 2026.
            Receipt number 99123.
            Your card ending in 4242 will be charged $20.00 automatically after your trial ends.
            """
        case .googleCloud:
            return """
            Welcome to your Google Cloud free trial
            Your 30 day free trial ends on April 30, 2026.
            Payment method Visa ending in 1111.
            After your trial ends, you will be charged $300.00 automatically.
            Invoice ID 1234.
            """
        case .granola:
            return """
            Your Granola Business free trial has started
            Your 14 day free trial starts now.
            The trial ends automatically when it expires, no credit card needed.
            """
        case .loom:
            return """
            Your Loom free trial starts now
            Your 14 day free trial starts now.
            No payment info required.
            Trial ends on March 15, 2026.
            """
        case .zapier:
            return """
            Your Zapier free trial has started
            Your free trial has started.
            Trial ends on March 20, 2026.
            No credit card needed to continue.
            """
        }
    }

    var expectedConfidence: TrialConfidenceTier {
        switch self {
        case .microsoft365, .anthropicClaude, .googleCloud:
            return .high
        case .granola, .loom, .zapier:
            return .medium
        }
    }

    var expectedEvent: TrialMessageEvent {
        switch self {
        case .microsoft365, .anthropicClaude, .googleCloud:
            return .trialConfirmation
        case .granola, .loom, .zapier:
            return .trialStarted
        }
    }

    var expectedWillAutoCharge: Bool {
        switch self {
        case .microsoft365, .anthropicClaude, .googleCloud:
            return true
        case .granola, .loom, .zapier:
            return false
        }
    }
}

// MARK: - OCR degradation

private enum OCRLevel: CaseIterable {
    case light
    case medium
    case heavy
}

private func ocrDegrade(_ text: String, level: OCRLevel) -> String {
    switch level {
    case .light:
        return text.replacingOccurrences(of: "\n\n", with: "\n")
    case .medium:
        var degraded = text
        degraded = degraded.replacingOccurrences(of: " 0.00", with: " O.OO")
        degraded = degraded.replacingOccurrences(of: "1111", with: "llll")
        degraded = degraded.replacingOccurrences(of: "automatically", with: "auto-\nmatically")
        return degraded
    case .heavy:
        var degraded = text
        degraded = degraded.replacingOccurrences(of: "$", with: "S")
        degraded = degraded.replacingOccurrences(of: "USD 0.00", with: "USD O.OO")
        degraded = degraded.replacingOccurrences(of: "USD 4.99", with: "USD 4.9g")
        degraded = degraded.replacingOccurrences(of: "\n", with: " ")
        return degraded
    }
}
