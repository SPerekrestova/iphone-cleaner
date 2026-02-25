import Foundation
import SwiftData

enum IssueCategory: String, Codable, CaseIterable, Sendable {
    case duplicate
    case similar
    case blurry
    case screenshot

    var displayName: String {
        switch self {
        case .duplicate: "Duplicates"
        case .similar: "Similar"
        case .blurry: "Blurry"
        case .screenshot: "Screenshots"
        }
    }

    var systemImage: String {
        switch self {
        case .duplicate: "doc.on.doc"
        case .similar: "square.on.square"
        case .blurry: "camera.metering.unknown"
        case .screenshot: "rectangle.on.rectangle"
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
    var createdAt: Date

    init(
        assetId: String,
        category: IssueCategory,
        confidence: Double,
        fileSize: Int64,
        userDecision: UserDecision = .pending,
        groupId: String? = nil,
        embedding: [Float]? = nil
    ) {
        self.assetId = assetId
        self.category = category
        self.confidence = confidence
        self.fileSize = fileSize
        self.userDecision = userDecision
        self.groupId = groupId
        self.embedding = embedding
        self.createdAt = Date()
    }

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
