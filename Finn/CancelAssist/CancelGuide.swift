import Foundation

struct CancelGuide: Codable, Equatable {
    let steps: [String]
    let directURL: String?
    let notes: String?
}
