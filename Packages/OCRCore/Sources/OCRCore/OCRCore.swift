public enum TrialOCRError: Error {
    case invalidImage
    case visionFailure(Error)
}

#if os(iOS) && canImport(UIKit) && canImport(Vision)
import Foundation
import UIKit
import Vision

public enum TrialOCRService {
    /// Recognize text in `image` using Apple Vision.
    /// Returns recognized lines joined by newline. Empty string if nothing recognized.
    /// Throws only on Vision-internal failure.
    public static func recognize(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw TrialOCRError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let resumer = OCRContinuationResumer(continuation)
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    resumer.resume(throwing: TrialOCRError.visionFailure(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    resumer.resume(returning: "")
                    return
                }

                let lines = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }
                resumer.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.0

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                resumer.resume(throwing: TrialOCRError.visionFailure(error))
            }
        }
    }
}

private final class OCRContinuationResumer: @unchecked Sendable {
    private let continuation: CheckedContinuation<String, any Error>
    private let lock = NSLock()
    private var didResume = false

    init(_ continuation: CheckedContinuation<String, any Error>) {
        self.continuation = continuation
    }

    func resume(returning value: String) {
        resumeOnce {
            continuation.resume(returning: value)
        }
    }

    func resume(throwing error: TrialOCRError) {
        resumeOnce {
            continuation.resume(throwing: error)
        }
    }

    private func resumeOnce(_ resume: () -> Void) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()

        resume()
    }
}
#endif
