import Foundation
import SwiftData

@Model
final class RLEEntry {
    var date: Date
    var imageFileName: String?
    var aiSupport: String?
    var aiGeneratedAt: Date?

    init(
        date: Date,
        imageFileName: String? = nil,
        aiSupport: String? = nil,
        aiGeneratedAt: Date? = nil
    ) {
        self.date = date
        self.imageFileName = imageFileName
        self.aiSupport = aiSupport
        self.aiGeneratedAt = aiGeneratedAt
    }
}
