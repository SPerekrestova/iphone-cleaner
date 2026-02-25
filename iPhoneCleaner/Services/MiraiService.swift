import Foundation
#if canImport(Uzu)
import Uzu
#endif

final class MiraiService {
    // SDK-dependent properties
    #if canImport(Uzu)
    private var engine: UzuEngine?
    private var chatModel: ChatModel?
    #endif

    func initialize(apiKey: String) async throws {
        #if canImport(Uzu)
        engine = try await UzuEngine.create(apiKey: apiKey)
        #else
        throw MiraiError.notInitialized
        #endif
    }

    func loadModel(repoId: String = "Qwen/Qwen3-0.6B") async throws {
        #if canImport(Uzu)
        guard let engine else { throw MiraiError.notInitialized }
        let model = try await engine.chatModel(repoId: repoId)
        try await engine.downloadChatModel(model) { update in
            print("Model download progress: \(update.progress)")
        }
        self.chatModel = model
        #else
        throw MiraiError.notInitialized
        #endif
    }

    func generateAppSuggestions(for apps: [AppInfo]) async throws -> String {
        #if canImport(Uzu)
        guard let engine, let model = chatModel else {
            throw MiraiError.notInitialized
        }
        let prompt = Self.buildAppSuggestionPrompt(for: apps)
        let session = try engine.chatSession(model)
        let input: Input = .messages(messages: [
            Message(role: .system, content: """
                You are a helpful iPhone storage assistant. Analyze the user's installed apps \
                and provide brief, actionable suggestions for which apps to delete to free up space. \
                Focus on large, rarely-used apps. Be concise — one line per app suggestion.
                """),
            Message(role: .user, content: prompt)
        ])
        let config = RunConfig().tokensLimit(512).enableThinking(false)
        let output = try session.run(input: input, config: config) { _ in true }
        return output.text.original
        #else
        throw MiraiError.notInitialized
        #endif
    }

    static func buildAppSuggestionPrompt(for apps: [AppInfo]) -> String {
        var lines = ["Here are my installed apps:\n"]
        for app in apps.sorted(by: { $0.cleanupScore > $1.cleanupScore }) {
            let lastUsed: String
            if let days = app.daysSinceLastUsed {
                lastUsed = "\(days) days ago"
            } else {
                lastUsed = "unknown"
            }
            lines.append("- \(app.name): \(app.sizeFormatted), last used: \(lastUsed)")
        }
        lines.append("\nWhich apps should I consider deleting to free up space?")
        return lines.joined(separator: "\n")
    }

    enum MiraiError: Error {
        case notInitialized
        case modelNotLoaded
    }
}
