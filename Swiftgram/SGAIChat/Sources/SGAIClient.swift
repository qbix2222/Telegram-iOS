import Foundation

public struct SGAIProvider: Codable, Equatable {
    public var name: String
    public var endpoint: String
    public var apiKey: String
    public var model: String
    public var systemPrompt: String
    public var temperature: Double

    public init(name: String, endpoint: String, apiKey: String, model: String, systemPrompt: String, temperature: Double) {
        self.name = name
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
        self.systemPrompt = systemPrompt
        self.temperature = temperature
    }
}

public struct SGAIModel: Codable, Equatable {
    public let id: String
    public let ownedBy: String

    public init(id: String, ownedBy: String) {
        self.id = id
        self.ownedBy = ownedBy
    }
}

public enum SGAIError: Error, LocalizedError {
    case badURL
    case http(Int, String)
    case noData

    public var errorDescription: String? {
        switch self {
        case .badURL: return "Invalid endpoint URL"
        case .http(let code, let body): return "HTTP \(code): \(body.prefix(300))"
        case .noData: return "Empty response"
        }
    }
}

public final class SGAIProviderStore {
    public static let shared = SGAIProviderStore()

    private let queue = DispatchQueue(label: "com.swiftgram.aiProvider")
    private var providers: [SGAIProvider] = []
    private var activeIndex: Int = 0
    private var loaded = false

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("sg_ai_providers.json")
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode([SGAIProvider].self, from: data) else { return }
        providers = decoded
        activeIndex = min(Int(UserDefaults.standard.integer(forKey: "sgAIActiveProvider")), max(decoded.count - 1, 0))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(providers) {
            try? data.write(to: fileURL, options: .atomic)
        }
        UserDefaults.standard.set(activeIndex, forKey: "sgAIActiveProvider")
    }

    public var all: [SGAIProvider] {
        return queue.sync {
            loadIfNeeded()
            return providers
        }
    }

    public var active: SGAIProvider? {
        return queue.sync {
            loadIfNeeded()
            guard providers.indices.contains(activeIndex) else { return nil }
            return providers[activeIndex]
        }
    }

    public func activeIndexValue() -> Int {
        return queue.sync {
            loadIfNeeded()
            return activeIndex
        }
    }

    public func save(_ provider: SGAIProvider, at index: Int?) {
        queue.sync {
            loadIfNeeded()
            if let index, providers.indices.contains(index) {
                providers[index] = provider
            } else {
                providers.append(provider)
                activeIndex = providers.count - 1
            }
            persist()
        }
    }

    public func remove(at index: Int) {
        queue.sync {
            loadIfNeeded()
            guard providers.indices.contains(index) else { return }
            providers.remove(at: index)
            activeIndex = min(activeIndex, max(providers.count - 1, 0))
            persist()
        }
    }

    public func activate(_ index: Int) {
        queue.sync {
            loadIfNeeded()
            guard providers.indices.contains(index) else { return }
            activeIndex = index
            persist()
        }
    }
}

public final class SGAIClient {
    public static let shared = SGAIClient()

    public func fetchModels(endpoint: String, apiKey: String, completion: @escaping (Result<[SGAIModel], SGAIError>) -> Void) {
        guard let url = normalizedModelsURL(endpoint) else {
            completion(.failure(.badURL))
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.http(-1, error.localizedDescription)))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.noData))
                return
            }
            guard let data else {
                completion(.failure(.noData))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                completion(.failure(.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")))
                return
            }
            let models = Self.parseModels(data)
            completion(.success(models))
        }.resume()
    }

    static func parseModels(_ data: Data) -> [SGAIModel] {
        struct ModelsResponse: Decodable {
            struct ModelEntry: Decodable {
                let id: String
                let owned_by: String?
            }
            let data: [ModelEntry]
        }
        if let decoded = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
            return decoded.data.map { SGAIModel(id: $0.id, ownedBy: $0.owned_by ?? "") }.sorted { $0.id < $1.id }
        }
        if let array = try? JSONDecoder().decode([String].self, from: data) {
            return array.map { SGAIModel(id: $0, ownedBy: "") }.sorted { $0.id < $1.id }
        }
        return []
    }

    private func normalizedModelsURL(_ endpoint: String) -> URL? {
        var base = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") {
            base.removeLast()
        }
        if base.hasSuffix("/chat/completions") {
            base = String(base.dropLast("/chat/completions".count))
        } else if base.hasSuffix("/models") {
            base = String(base.dropLast("/models".count))
        }
        if base.hasSuffix("/v1") {
            base += "/models"
        } else {
            base += "/v1/models"
        }
        return URL(string: base)
    }

    public func chat(provider: SGAIProvider, history: [(role: String, content: String)], completion: @escaping (Result<String, SGAIError>) -> Void) {
        guard let url = normalizedChatURL(provider.endpoint) else {
            completion(.failure(.badURL))
            return
        }
        struct Message: Codable {
            let role: String
            let content: String
        }
        struct Body: Codable {
            let model: String
            let messages: [Message]
            let temperature: Double
            let stream: Bool
        }
        var messages: [Message] = []
        if !provider.systemPrompt.isEmpty {
            messages.append(Message(role: "system", content: provider.systemPrompt))
        }
        for entry in history {
            messages.append(Message(role: entry.role, content: entry.content))
        }
        guard let bodyData = try? JSONEncoder().encode(Body(model: provider.model, messages: messages, temperature: provider.temperature, stream: false)) else {
            completion(.failure(.noData))
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !provider.apiKey.isEmpty {
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        }
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.http(-1, error.localizedDescription)))
                return
            }
            guard let http = response as? HTTPURLResponse, let data else {
                completion(.failure(.noData))
                return
            }
            guard (200..<300).contains(http.statusCode) else {
                completion(.failure(.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")))
                return
            }
            completion(.success(Self.parseChatResponse(data)))
        }.resume()
    }

    private func normalizedChatURL(_ endpoint: String) -> URL? {
        var base = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") {
            base.removeLast()
        }
        if base.hasSuffix("/models") {
            base = String(base.dropLast("/models".count))
        }
        if !base.hasSuffix("/chat/completions") {
            if base.hasSuffix("/v1") {
                base += "/chat/completions"
            } else {
                base += "/v1/chat/completions"
            }
        }
        return URL(string: base)
    }

    static func parseChatResponse(_ data: Data) -> String {
        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable {
                    let content: String?
                }
                let message: Msg
            }
            let choices: [Choice]
        }
        if let decoded = try? JSONDecoder().decode(ChatResponse.self, from: data), let first = decoded.choices.first {
            return first.message.content ?? ""
        }
        return ""
    }
}
