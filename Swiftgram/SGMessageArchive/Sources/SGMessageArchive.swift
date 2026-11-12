import Foundation
import Postbox

public final class ArchivedDeletedMessage: Codable {
    public let peerId: Int64
    public let messageId: Int32
    public let namespace: Int32
    public let globallyUniqueId: Int64?
    public let timestamp: Int32
    public let deletedAt: Int32
    public let authorId: Int64?
    public let text: String
    public let mediaSummary: [String]
    public let isOutgoing: Bool
    public let serializedMessage: Data

    public init(peerId: Int64, messageId: Int32, namespace: Int32, globallyUniqueId: Int64?, timestamp: Int32, deletedAt: Int32, authorId: Int64?, text: String, mediaSummary: [String], isOutgoing: Bool, serializedMessage: Data) {
        self.peerId = peerId
        self.messageId = messageId
        self.namespace = namespace
        self.globallyUniqueId = globallyUniqueId
        self.timestamp = timestamp
        self.deletedAt = deletedAt
        self.authorId = authorId
        self.text = text
        self.mediaSummary = mediaSummary
        self.isOutgoing = isOutgoing
        self.serializedMessage = serializedMessage
    }
}

public final class SGMessageArchiveStore {
    public static let shared = SGMessageArchiveStore()

    public var isEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "sgMessageArchiveEnabled") || !UserDefaults.standard.bool(forKey: "sgMessageArchiveConfigured")
    }

    private let queue = DispatchQueue(label: "com.swiftgram.messageArchive")
    private let maxMessages = 50000

    private var cache: [Int64: [Int32: ArchivedDeletedMessage]] = [:]
    private var order: [(peerId: Int64, messageId: Int32)] = []
    private var loaded = false

    private var archiveURL: URL {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("SGMessageArchive", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("archive.json")
    }

    private init() {
        queue.async { self.loadIfNeeded() }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        let url = self.archiveURL
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        if let messages = try? decoder.decode([ArchivedDeletedMessage].self, from: data) {
            for m in messages {
                let peerId = m.peerId
                if cache[peerId] == nil { cache[peerId] = [:] }
                cache[peerId]?[m.messageId] = m
                order.append((peerId, m.messageId))
            }
        }
    }

    private func persist() {
        var messages: [ArchivedDeletedMessage] = []
        for (_, dict) in cache {
            for (_, m) in dict {
                messages.append(m)
            }
        }
        messages.sort { $0.deletedAt < $1.deletedAt }
        if messages.count > maxMessages {
            messages.removeFirst(messages.count - maxMessages)
        }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(messages) {
            try? data.write(to: archiveURL, options: .atomic)
        }
    }

    public func archiveMessage(_ message: Message, deletedAt: Int32) {
        queue.sync(execute: {
            loadIfNeeded()
            guard case let .Id(id) = message.id else { return }
            let key = id.peerId.toInt64()
            if cache[key]?[id.id] != nil { return }

            let mediaSummary = message.media.map { media -> String in
                String(describing: type(of: media))
            }

            let archived = ArchivedDeletedMessage(
                peerId: key,
                messageId: id.id,
                namespace: id.namespace,
                globallyUniqueId: message.globallyUniqueId,
                timestamp: message.timestamp,
                deletedAt: deletedAt,
                authorId: message.authorId?.toInt64(),
                text: message.text,
                mediaSummary: mediaSummary,
                isOutgoing: !message.flags.contains(.Incoming),
                serializedMessage: Data()
            )
            if cache[key] == nil { cache[key] = [:] }
            cache[key]?[id.id] = archived
            order.append((key, id.id))
            if order.count > maxMessages {
                let drop = order.removeFirst(order.count - maxMessages)
                for d in drop {
                    cache[d.peerId]?.removeValue(forKey: d.messageId)
                }
            }
            persist()
        })
    }


    public func archive(messageIds: [MessageId], transaction: Transaction) {
        let timestamp = Int32(Date().timeIntervalSince1970)
        for id in messageIds {
            guard let message = transaction.getMessage(id) else { continue }
            self.archiveMessage(message, deletedAt: timestamp)
        }
    }

    public func archiveEdit(messageId: MessageId, transaction: Transaction) {
        guard let message = transaction.getMessage(messageId) else { return }
        queue.sync(execute: {
            loadIfNeeded()
            guard case let .Id(id) = message.id else { return }
            let key = id.peerId.toInt64()
            guard let existing = cache[key]?[id.id] else { return }
            if existing.text == message.text { return }
            let edited = ArchivedDeletedMessage(
                peerId: existing.peerId,
                messageId: existing.messageId,
                namespace: existing.namespace,
                globallyUniqueId: existing.globallyUniqueId,
                timestamp: existing.timestamp,
                deletedAt: existing.deletedAt,
                authorId: existing.authorId,
                text: existing.text + "\n[edit] " + message.text,
                mediaSummary: existing.mediaSummary,
                isOutgoing: existing.isOutgoing,
                serializedMessage: existing.serializedMessage
            )
            cache[key]?[id.id] = edited
            persist()
        })
    }

    public func archivedMessages(peerId: PeerId) -> [ArchivedDeletedMessage] {
        return queue.sync(execute: {
            loadIfNeeded()
            return (cache[peerId.toInt64()]?.values.map { $0 } ?? []).sorted { $0.messageId < $1.messageId }
        })
    }

    public func archivedMessage(peerId: PeerId, messageId: Int32) -> ArchivedDeletedMessage? {
        return queue.sync(execute: {
            loadIfNeeded()
            return cache[peerId.toInt64()]?[messageId]
        })
    }

    public func totalCount() -> Int {
        return queue.sync(execute: {
            loadIfNeeded()
            return order.count
        })
    }

    public func clearAll() {
        queue.sync(execute: {
            cache.removeAll()
            order.removeAll()
            try? FileManager.default.removeItem(at: archiveURL)
        })
    }

    public func clear(peerId: PeerId) {
        queue.sync(execute: {
            cache.removeValue(forKey: peerId.toInt64())
            order.removeAll { $0.peerId == peerId.toInt64() }
            persist()
        })
    }
}
