#if canImport(UIKit)
import Foundation
import UIKit
import Vision

enum TrialOCRError: Error {
    case invalidImage
    case visionFailure(Error)
}

enum TrialOCRService {
    /// Recognize text in `image` using Apple Vision.
    /// Returns recognized lines joined by newline. Empty string if nothing recognized.
    /// Throws only on Vision-internal failure.
    static func recognize(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw TrialOCRError.invalidImage }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: TrialOCRError.visionFailure(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let lines = observations.compactMap { obs in
                    obs.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.0

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TrialOCRError.visionFailure(error))
            }
        }
    }
}
#endif
