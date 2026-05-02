import OCRCore
import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
    private var didStart = false
    private var recognizedImageText: String?

    private let statusLabel = UILabel()
    private let buttonStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        statusLabel.text = "Reading image..."
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        buttonStack.axis = .vertical
        buttonStack.spacing = 12
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.isHidden = true

        let trialButton = makeChoiceButton(title: "Free trial", action: #selector(saveFreeTrial))
        let subscriptionButton = makeChoiceButton(title: "Subscription", action: #selector(saveSubscription))
        buttonStack.addArrangedSubview(trialButton)
        buttonStack.addArrangedSubview(subscriptionButton)

        view.addSubview(statusLabel)
        view.addSubview(buttonStack)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -48),

            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            buttonStack.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 24),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true

        Task {
            await handleShare()
        }
    }

    private func handleShare() async {
        if let image = await sharedImage() {
            await recognize(image)
            return
        }

        await openFinnWithSharedText()
    }

    private func recognize(_ image: UIImage) async {
        do {
            let text = try await TrialOCRService.recognize(from: image)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                await finish()
                return
            }

            await MainActor.run {
                recognizedImageText = text
                statusLabel.text = ""
                buttonStack.isHidden = false
            }
        } catch {
            await finish()
        }
    }

    private func openFinnWithSharedText() async {
        guard let text = await sharedText(),
              let url = deepLinkURL(for: text) else {
            await finish()
            return
        }

        extensionContext?.open(url) { [weak self] _ in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func sharedText() async -> String? {
        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        let preferredTypes = [
            UTType.plainText.identifier,
            UTType.text.identifier,
            UTType.html.identifier,
            UTType.url.identifier,
        ]

        for type in preferredTypes {
            for provider in providers where provider.hasItemConformingToTypeIdentifier(type) {
                if let text = await loadText(from: provider, typeIdentifier: type) {
                    return text
                }
            }
        }

        return nil
    }

    private func sharedImage() async -> UIImage? {
        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        let imageTypes = [
            UTType.image.identifier,
            UTType.png.identifier,
            UTType.jpeg.identifier,
        ]

        for type in imageTypes {
            for provider in providers where provider.hasItemConformingToTypeIdentifier(type) {
                if let image = await loadImage(from: provider, typeIdentifier: type) {
                    return image
                }
            }
        }

        return nil
    }

    private func loadImage(from provider: NSItemProvider, typeIdentifier: String) async -> UIImage? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                let image: UIImage?
                switch item {
                case let uiImage as UIImage:
                    image = uiImage
                case let data as Data:
                    image = UIImage(data: data)
                case let url as URL:
                    image = UIImage(contentsOfFile: url.path)
                default:
                    image = nil
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func loadText(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                let text: String?
                switch item {
                case let string as String:
                    text = string
                case let data as Data:
                    text = String(data: data, encoding: .utf8)
                case let url as URL:
                    text = url.absoluteString
                default:
                    text = nil
                }

                continuation.resume(returning: text?.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    private func deepLinkURL(for text: String) -> URL? {
        guard !text.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "finn"
        components.host = "shared-trial"
        components.queryItems = [
            URLQueryItem(name: "text", value: text),
        ]
        return components.url
    }

    private func makeChoiceButton(title: String, action: Selector) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .label
        configuration.baseForegroundColor = .systemBackground
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)

        let button = UIButton(configuration: configuration, primaryAction: nil)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func saveFreeTrial() {
        savePendingImageShare(kind: .freeTrial)
    }

    @objc private func saveSubscription() {
        savePendingImageShare(kind: .subscription)
    }

    private func savePendingImageShare(kind: ShareEntryKind) {
        guard let recognizedImageText else {
            extensionContext?.completeRequest(returningItems: nil)
            return
        }

        do {
            try ShareHandoffStore.append(PendingShareEntry(
                kind: kind,
                recognizedText: recognizedImageText
            ))
        } catch {
            // Keep the extension quiet; PR 4 adds host-app confirmation UI.
        }

        extensionContext?.completeRequest(returningItems: nil)
    }

    @MainActor
    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
