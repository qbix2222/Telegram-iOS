import Foundation

public struct SGAIMessage: Codable {
    public let role: String
    public let content: String
    public let timestamp: Double

    public init(role: String, content: String, timestamp: Double = Date().timeIntervalSince1970) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

public final class SGAIChatHistoryStore {
    public static let shared = SGAIChatHistoryStore()

    private let queue = DispatchQueue(label: "com.swiftgram.aiHistory")

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("sg_ai_history.json")
    }

    private func load() -> [SGAIMessage] {
        guard let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode([SGAIMessage].self, from: data) else { return [] }
        return decoded
    }

    private func persist(_ messages: [SGAIMessage]) {
        if let data = try? JSONEncoder().encode(messages) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public func history() -> [SGAIMessage] {
        return queue.sync { load() }
    }

    public func append(_ message: SGAIMessage) {
        queue.sync {
            var messages = load()
            messages.append(message)
            if messages.count > 500 {
                messages.removeFirst(messages.count - 500)
            }
            persist(messages)
        }
    }

    public func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    public func requestContext(limit: Int = 30) -> [(role: String, content: String)] {
        return queue.sync {
            let messages = load().suffix(limit)
            return messages.map { (role: $0.role, content: $0.content) }
        }
    }
}
