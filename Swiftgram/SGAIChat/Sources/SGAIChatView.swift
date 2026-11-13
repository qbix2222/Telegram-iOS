import Foundation
import SwiftUI
import SGSwiftUI
import SGStrings
import AccountContext

struct SGAIChatView: View {
    @Environment(\.lang) var lang: String
    @State private var messages: [SGAIMessage] = SGAIChatHistoryStore.shared.history()
    @State private var input: String = ""
    @State private var waiting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            HStack {
                                if message.role == "user" { Spacer() }
                                Text(message.content)
                                    .padding(10)
                                    .background(message.role == "user" ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                                    .cornerRadius(14)
                                if message.role != "user" { Spacer() }
                            }
                            .id(index)
                        }
                        if waiting {
                            HStack {
                                ProgressView()
                                Text("Settings.AI.Thinking".i18n(lang)).font(.caption).foregroundColor(.secondary)
                                Spacer()
                            }.padding(.horizontal, 10)
                        }
                        if let errorMessage {
                            Text(errorMessage).font(.caption).foregroundColor(.red).padding(.horizontal, 10)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .onChange(of: messages.count) { count in
                    if count > 0 {
                        withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
                    }
                }
            }
            Divider()
            HStack(spacing: 8) {
                TextField("Settings.AI.InputPlaceholder".i18n(lang), text: $input)
                    .padding(8)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(18)
                Button {
                    send()
                } label: {
                    Image(systemName: waiting ? "hourglass" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(input.isEmpty || waiting ? .secondary : .accentColor)
                }
                .disabled(input.isEmpty || waiting)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .navigationTitle("Settings.AI.Chat".i18n(lang))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        SGAIChatHistoryStore.shared.clear()
                        messages = []
                    } label: {
                        Label("Settings.AI.ClearChat".i18n(lang), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let provider = SGAIProviderStore.shared.active else { return }
        input = ""
        errorMessage = nil
        let userMessage = SGAIMessage(role: "user", content: text)
        messages.append(userMessage)
        SGAIChatHistoryStore.shared.append(userMessage)
        waiting = true
        let history = SGAIChatHistoryStore.shared.requestContext()
        SGAIClient.shared.chat(provider: provider, history: history) { result in
            DispatchQueue.main.async {
                waiting = false
                switch result {
                case .success(let reply):
                    let replyMessage = SGAIMessage(role: "assistant", content: reply.isEmpty ? "…" : reply)
                    messages.append(replyMessage)
                    SGAIChatHistoryStore.shared.append(replyMessage)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
