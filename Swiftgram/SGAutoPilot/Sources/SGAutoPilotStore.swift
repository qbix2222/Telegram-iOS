import Foundation
import Postbox
import TelegramCore

public struct SGAutoPilotChatConfig: Codable {
    public var peerId: Int64
    public var systemPrompt: String
    public var contextMessageCount: Int32
    public var typingDelaySeconds: Double
    public var activeHoursEnabled: Bool
    public var activeHourStart: Int32
    public var activeHourEnd: Int32
    public var enabled: Bool

    public init(peerId: Int64, systemPrompt: String, contextMessageCount: Int32 = 10, typingDelaySeconds: Double = 2.0, activeHoursEnabled: Bool = false, activeHourStart: Int32 = 9, activeHourEnd: Int32 = 23, enabled: Bool = true) {
        self.peerId = peerId
        self.systemPrompt = systemPrompt
        self.contextMessageCount = contextMessageCount
        self.typingDelaySeconds = typingDelaySeconds
        self.activeHoursEnabled = activeHoursEnabled
        self.activeHourStart = activeHourStart
        self.activeHourEnd = activeHourEnd
        self.enabled = enabled
    }
}

public final class SGAutoPilotStore {
    public static let shared = SGAutoPilotStore()

    private let queue = DispatchQueue(label: "com.swiftgram.autoPilot")
    private var configs: [Int64: SGAutoPilotChatConfig] = [:]
    private var loaded = false
    private var processing: Set<Int64> = []

    private var storeURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SGAutoPilot", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("configs.json")
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: storeURL), let decoded = try? JSONDecoder().decode([SGAutoPilotChatConfig].self, from: data) else { return }
        for c in decoded {
            configs[c.peerId] = c
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(Array(configs.values)) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    public var enabledPeerIds: [Int64] {
        return queue.sync(execute: {
            loadIfNeeded()
            return configs.values.filter { $0.enabled }.map { $0.peerId }
        })
    }

    public func config(peerId: Int64) -> SGAutoPilotChatConfig? {
        return queue.sync(execute: {
            loadIfNeeded()
            return configs[peerId]
        })
    }

    public func setConfig(_ config: SGAutoPilotChatConfig) {
        _ = queue.sync { () -> Void in
            loadIfNeeded()
            configs[config.peerId] = config
            persist()
        })
    }

    public func removeConfig(peerId: Int64) {
        _ = queue.sync { () -> Void in
            loadIfNeeded()
            configs.removeValue(forKey: peerId)
            persist()
        })
    }

    public func isBusy(peerId: Int64) -> Bool {
        return queue.sync(execute: { processing.contains(peerId) })
    }

    public func setBusy(peerId: Int64, busy: Bool) {
        _ = queue.sync { () -> Void in
            if busy {
                processing.insert(peerId)
            } else {
                processing.remove(peerId)
            }
        })
    }

    public func isInActiveHours(_ config: SGAutoPilotChatConfig, date: Date = Date()) -> Bool {
        guard config.activeHoursEnabled else { return true }
        let hour = Calendar.current.component(.hour, from: date)
        if config.activeHourStart <= config.activeHourEnd {
            return hour >= config.activeHourStart && hour < config.activeHourEnd
        }
        return hour >= config.activeHourStart || hour < config.activeHourEnd
    }
}
