import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
import AccountContext
import SGAIChat

public final class SGAutoPilotEngine {
    public static let shared = SGAutoPilotEngine()

    private var disposable: Disposable?

    public func start(context: AccountContext) {
        guard disposable == nil else { return }
        disposable = (context.account.stateManager.notificationMessages
        |> deliverOnMainQueue).start(next: { [weak context] messageList in
            guard let context else { return }
            for (messages, _, _, _) in messageList {
                for message in messages {
                    SGAutoPilotEngine.shared.handleIncoming(message: message, context: context)
                }
            }
        })
    }

    private func handleIncoming(message: Message, context: AccountContext) {
        let peerId = message.id.peerId
        if peerId == context.account.peerId {
            return
        }
        guard let config = SGAutoPilotStore.shared.config(peerId: peerId.toInt64()), config.enabled else {
            return
        }
        guard SGAutoPilotStore.shared.isInActiveHours(config) else {
            return
        }
        guard !SGAutoPilotStore.shared.isBusy(peerId: peerId.toInt64()) else {
            return
        }
        guard message.flags.contains(.Incoming), !message.text.isEmpty else {
            return
        }
        guard let provider = SGAIProviderStore.shared.active else {
            return
        }

        SGAutoPilotStore.shared.setBusy(peerId: peerId.toInt64(), busy: true)

        let historyStore = SGAIChatHistoryStore.shared
        var history: [(role: String, content: String)] = historyStore.history().suffix(Int(config.contextMessageCount)).map { ($0.role, $0.content) }
        history.append(("user", message.text))

        SGAIClient.shared.chat(provider: provider, history: history) { [weak context] result in
            guard let context else {
                SGAutoPilotStore.shared.setBusy(peerId: peerId.toInt64(), busy: false)
                return
            }
            switch result {
            case let .success(reply):
                let delay = max(0.5, min(10.0, config.typingDelaySeconds + Double(reply.count) * 0.02))
                let timer = SwiftSignalKit.Timer(timeout: delay, repeat: false, completion: { [weak context] in
                    guard let context else { return }
                    let _ = enqueueMessages(account: context.account, peerId: peerId, messages: [.message(
                        text: reply,
                        attributes: [],
                        inlineStickers: [:],
                        mediaReference: nil,
                        threadId: nil,
                        replyToMessageId: nil,
                        replyToStoryId: nil,
                        localGroupingKey: nil,
                        correlationId: nil,
                        bubbleUpEmojiOrStickersets: []
                    )]).start(completed: {
                        SGAutoPilotStore.shared.setBusy(peerId: peerId.toInt64(), busy: false)
                    })
                }, queue: Queue.mainQueue())
                timer.start()
            case let .failure(error):
                SGAutoPilotStore.shared.setBusy(peerId: peerId.toInt64(), busy: false)
                SGAutoPilotEngine.recordError(peerId: peerId, error: error.localizedDescription)
            }
        }
    }

    static func recordError(peerId: PeerId, error: String) {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("SGAutoPilot", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let line = "\(Date().timeIntervalSince1970)\t\(peerId.toInt64())\t\(error)\n"
        if let handle = FileHandle(forWritingAtPath: dir.appendingPathComponent("errors.log").path) {
            _ = try? handle.seekToEnd()
            handle.write(line.data(using: .utf8) ?? Data())
            _ = try? handle.close()
        } else {
            try? line.data(using: .utf8)?.write(to: dir.appendingPathComponent("errors.log"))
        }
    }
}
