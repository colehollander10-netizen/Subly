import UniformTypeIdentifiers
import UIKit

final class ShareViewController: UIViewController {
    private var didStart = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "Opening Finn..."
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true

        Task {
            await openFinn()
        }
    }

    private func openFinn() async {
        guard let text = await sharedText(),
              let url = deepLinkURL(for: text) else {
            extensionContext?.completeRequest(returningItems: nil)
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
}
