import Foundation
import Testing
import EmailParsingCore

struct SubscriptionParserFixtureTests {
    private let referenceNow = ISO8601DateFormatter().date(from: "2026-03-05T12:00:00Z")!

    @Test
    func corpusFixturesClassifyAsExpected() {
        for fixture in ParserFixture.allCases {
            let classification = TrialParser.classifyWithDiagnostics(
                fixture.message,
                now: referenceNow
            )

            #expect(classification.confidence == fixture.expectedConfidence)
            #expect(classification.willAutoCharge == fixture.expectedWillAutoCharge)
            #expect(classification.event == fixture.expectedEvent)
            #expect(classification.rejectionReason == fixture.expectedRejectionReason)
        }
    }

    @Test
    func aggregatePrefersHighConfidenceTrialOverSameDomainNoise() {
        let batch = TrialParser.analyze(
            [
                ParserFixture.microsoft365.message,
                makeMessage(
                    id: "m365-promo",
                    from: "Microsoft 365 <billing@microsoft.com>",
                    subject: "Just for you: 2 months of Microsoft 365 free trial",
                    body: """
                    Claim your free trial today.
                    Limited time offer.
                    """,
                    sentDate: iso("2026-02-10T12:00:00Z")
                ),
            ],
            now: referenceNow
        )

        #expect(batch.detectedTrials.count == 1)
        #expect(batch.detectedTrials.first?.senderDomain == "microsoft.com")
        #expect(batch.detectedLeads.isEmpty)
    }

    @Test
    func aggregateSurfacesMediumConfidenceWelcomeEmailAsLead() {
        let batch = TrialParser.analyze(
            [
                makeMessage(
                    id: "every-welcome",
                    from: "Every <team@every.to>",
                    subject: "Welcome to Every",
                    body: """
                    Welcome to Every. Your subscription has started today.
                    Get started with your member account.
                    """,
                    sentDate: iso("2026-02-18T12:00:00Z")
                ),
            ],
            now: referenceNow
        )

        #expect(batch.detectedTrials.isEmpty)
        #expect(batch.detectedLeads.count == 1)
        #expect(batch.detectedLeads.first?.senderDomain == "every.to")
    }

    @Test
    func marketingOfferStaysLowConfidenceAndDoesNotSurface() {
        let classification = TrialParser.classifyWithDiagnostics(
            makeMessage(
                id: "promo-offer",
                from: "Uber One <offer@uber.com>",
                subject: "Just for you: 2 months of Uber One free trial",
                body: """
                Claim your free trial today.
                Limited time offer.
                """,
                sentDate: iso("2026-02-11T12:00:00Z")
            ),
            now: referenceNow
        )

        #expect(classification.confidence == .low)
        #expect(classification.event == .promoMarketing)
        #expect(classification.rejectionReason == .marketingOffer)

        let batch = TrialParser.analyze([ParserFixture.microsoft365.message], now: referenceNow)
        #expect(batch.detectedTrials.count == 1)
        #expect(batch.detectedLeads.isEmpty)
    }
}

private enum ParserFixture: CaseIterable {
    case microsoft365
    case anthropicClaude
    case googleCloud
    case granola
    case loom
    case zapier

    var message: GmailMessage {
        switch self {
        case .microsoft365:
            return makeMessage(
                id: "m365",
                from: "Microsoft 365 <billing@microsoft.com>",
                subject: "Your purchase of Microsoft 365 Personal has been processed",
                body: """
                Your purchase of Microsoft 365 Personal has been processed
                Thanks for subscribing to Microsoft 365 Personal. We're happy you're here.

                We've charged USD 0.00 to PayPal.
                Starting Monday, October 19, 2026, your payment of USD 4.99 plus applicable taxes will be charged to PayPal automatically every 1 month.
                Renewal Date: October 19, 2026
                Order Number: 6924165080
                Plan Price: USD 4.99 plus applicable taxes/1 month
                """,
                sentDate: iso("2026-02-01T12:00:00Z")
            )
        case .anthropicClaude:
            return makeMessage(
                id: "claude",
                from: "Anthropic <billing@anthropic.com>",
                subject: "Your Claude Pro trial has started",
                body: """
                Your 7 day free trial has started.
                Trial ends on April 11, 2026.
                Receipt number 99123.
                Your card ending in 4242 will be charged $20.00 automatically after your trial ends.
                """,
                sentDate: iso("2026-03-04T12:00:00Z")
            )
        case .googleCloud:
            return makeMessage(
                id: "gcloud",
                from: "Google Cloud <billing-noreply@googlecloud.com>",
                subject: "Welcome to your Google Cloud free trial",
                body: """
                Welcome to your Google Cloud free trial.
                Your 30 day free trial ends on April 30, 2026.
                Payment method Visa ending in 1111.
                After your trial ends, you will be charged $300.00 automatically.
                Invoice ID 1234.
                """,
                sentDate: iso("2026-02-28T12:00:00Z")
            )
        case .granola:
            return makeMessage(
                id: "granola",
                from: "Granola <hello@granola.ai>",
                subject: "Your Granola Business free trial has started",
                body: """
                Your 14 day free trial starts now.
                The trial ends automatically when it expires, no credit card needed.
                """,
                sentDate: iso("2026-03-01T12:00:00Z")
            )
        case .loom:
            return makeMessage(
                id: "loom",
                from: "Loom <team@loom.com>",
                subject: "Your Loom free trial starts now",
                body: """
                Your 14 day free trial starts now.
                No payment info required.
                Trial ends on March 15, 2026.
                """,
                sentDate: iso("2026-03-01T12:00:00Z")
            )
        case .zapier:
            return makeMessage(
                id: "zapier",
                from: "Zapier <team@zapier.com>",
                subject: "Your Zapier free trial has started",
                body: """
                Your free trial has started.
                Trial ends on March 20, 2026.
                No credit card needed to continue.
                """,
                sentDate: iso("2026-03-06T12:00:00Z")
            )
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

    var expectedRejectionReason: TrialRejectionReason? {
        switch self {
        case .microsoft365, .anthropicClaude, .googleCloud:
            return nil
        case .granola, .loom, .zapier:
            return .noCardOnFile
        }
    }
}

private func makeMessage(
    id: String,
    from: String,
    subject: String,
    body: String,
    sentDate: Date
) -> GmailMessage {
    GmailMessage(
        id: id,
        threadId: "thread-\(id)",
        payload: MessagePayload(
            headers: [
                MessageHeader(name: "From", value: from),
                MessageHeader(name: "Subject", value: subject),
            ],
            body: MessageBody(
                data: encodeBase64URL(body),
                size: body.utf8.count
            ),
            parts: nil
        ),
        snippet: nil,
        internalDate: String(Int(sentDate.timeIntervalSince1970 * 1000))
    )
}

private func encodeBase64URL(_ value: String) -> String {
    Data(value.utf8)
        .base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func iso(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}
