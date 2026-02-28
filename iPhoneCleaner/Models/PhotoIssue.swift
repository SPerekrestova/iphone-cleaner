import Foundation
import SwiftData

enum IssueCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    var id: Self { self }

    case duplicate
    case similar
    case blurry
    case screenshot
    case screenRecording
    case lensSmudge
    case textHeavy
    case lowQuality

    var displayName: String {
        switch self {
        case .duplicate: "Duplicates"
        case .similar: "Similar"
        case .blurry: "Blurry"
        case .screenshot: "Screenshots"
        case .screenRecording: "Screen Recordings"
        case .lensSmudge: "Lens Smudge"
        case .textHeavy: "Text Heavy"
        case .lowQuality: "Low Quality"
        }
    }

    var systemImage: String {
        switch self {
        case .duplicate: "doc.on.doc"
        case .similar: "square.on.square"
        case .blurry: "camera.metering.unknown"
        case .screenshot: "rectangle.on.rectangle"
        case .screenRecording: "record.circle"
        case .lensSmudge: "drop.circle"
        case .textHeavy: "doc.text"
        case .lowQuality: "exclamationmark.triangle"
        }
    }
}

enum UserDecision: String, Codable {
    case pending
    case keep
    case delete
}

@Model
final class PhotoIssue {
    @Attribute(.unique) var assetId: String
    var category: IssueCategory
    var confidence: Double
    var fileSize: Int64
    var userDecision: UserDecision
    var groupId: String?
    var embedding: [Float]?
    var sceneTags: [String]?
    var aestheticsScore: Float?
    var isVideo: Bool
    var createdAt: Date

    init(
        assetId: String,
        category: IssueCategory,
        confidence: Double,
        fileSize: Int64,
        userDecision: UserDecision = .pending,
        groupId: String? = nil,
        embedding: [Float]? = nil,
        sceneTags: [String]? = nil,
        aestheticsScore: Float? = nil,
        isVideo: Bool = false
    ) {
        self.assetId = assetId
        self.category = category
        self.confidence = confidence
        self.fileSize = fileSize
        self.userDecision = userDecision
        self.groupId = groupId
        self.embedding = embedding
        self.sceneTags = sceneTags
        self.aestheticsScore = aestheticsScore
        self.isVideo = isVideo
        self.createdAt = Date()
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
