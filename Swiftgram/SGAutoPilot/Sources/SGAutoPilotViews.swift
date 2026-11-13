import Foundation
import SwiftUI
import SGSwiftUI
import SGStrings
import SGAIChat
import AccountContext
import Display
import TelegramPresentationData

public func sgAutoPilotController(context: AccountContext, presentationData: PresentationData? = nil) -> ViewController {
    let presentationData = presentationData ?? context.sharedContext.currentPresentationData.with { $0 }
    return SGSwiftUIController(
        title: "AutoPilot.Title".i18n(presentationData.strings.baseLanguageCode),
        presentationData: presentationData,
        presentationDataSignal: context.sharedContext.presentationData
    ) {
        SGAutoPilotRootView(context: context)
    }
}

struct SGAutoPilotRootView: View {
    @Environment(\.lang) var lang: String
    let context: AccountContext
    @State private var configs: [SGAutoPilotChatConfig] = []
    @State private var editing: SGAutoPilotChatConfig?

    var body: some View {
        List {
            Section {
                if configs.isEmpty {
                    Text("AutoPilot.Empty".i18n(lang))
                        .foregroundColor(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(configs, id: \.peerId) { config in
                        Button {
                            editing = config
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(config.peerId))
                                        .font(.body)
                                    Text(config.systemPrompt.isEmpty ? "AutoPilot.NoPrompt".i18n(lang) : config.systemPrompt)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: config.enabled ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(config.enabled ? .accentColor : .secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            SGAutoPilotStore.shared.removeConfig(peerId: configs[i].peerId)
                        }
                        reload()
                    }
                }
                Button {
                    let config = SGAutoPilotChatConfig(peerId: 0, systemPrompt: "")
                    editing = config
                } label: {
                    Label("AutoPilot.Add".i18n(lang), systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("AutoPilot.Header".i18n(lang))
            } footer: {
                Text("AutoPilot.Footer".i18n(lang))
            }
        }
        .navigationTitle("AutoPilot.Title".i18n(lang))
        .onAppear(perform: reload)
        .sheet(item: $editing) { config in
            SGAutoPilotEditView(context: context, initial: config) { updated in
                if let updated {
                    SGAutoPilotStore.shared.setConfig(updated)
                }
                reload()
            }
        }
    }

    private func reload() {
        let store = SGAutoPilotStore.shared
        var list: [SGAutoPilotChatConfig] = []
        for peerId in store.enabledPeerIds {
            if let c = store.config(peerId: peerId) { list.append(c) }
        }
        configs = list
    }
}

extension SGAutoPilotChatConfig: Identifiable {
    public var id: Int64 { peerId }
}

struct SGAutoPilotEditView: View {
    @Environment(\.lang) var lang: String
    @Environment(\.dismiss) var dismiss
    let context: AccountContext
    let initial: SGAutoPilotChatConfig
    let onDone: (SGAutoPilotChatConfig?) -> Void

    @State private var peerIdText: String
    @State private var systemPrompt: String
    @State private var contextCount: Int32
    @State private var typingDelay: Double
    @State private var enabled: Bool
    @State private var activeHours: Bool
    @State private var hourStart: Int32
    @State private var hourEnd: Int32

    init(context: AccountContext, initial: SGAutoPilotChatConfig, onDone: @escaping (SGAutoPilotChatConfig?) -> Void) {
        self.context = context
        self.initial = initial
        self.onDone = onDone
        _peerIdText = State(initialValue: initial.peerId == 0 ? "" : String(initial.peerId))
        _systemPrompt = State(initialValue: initial.systemPrompt)
        _contextCount = State(initialValue: initial.contextMessageCount)
        _typingDelay = State(initialValue: initial.typingDelaySeconds)
        _enabled = State(initialValue: initial.enabled)
        _activeHours = State(initialValue: initial.activeHoursEnabled)
        _hourStart = State(initialValue: initial.activeHourStart)
        _hourEnd = State(initialValue: initial.activeHourEnd)
    }

    var body: some View {
            Form {
                if initial.peerId == 0 {
                    TextField("AutoPilot.PeerId".i18n(lang), text: $peerIdText)
                        .keyboardType(.numberPad)
                }
                Section("AutoPilot.Prompt") {
                    TextEditor(text: $systemPrompt)
                        .frame(minHeight: 100)
                }
                Section("AutoPilot.Behavior") {
                    Toggle("AutoPilot.Enabled".i18n(lang), isOn: $enabled)
                    HStack {
                        Text("AutoPilot.Context".i18n(lang))
                        Spacer()
                        Text("\(contextCount)").foregroundColor(.secondary)
                    }
                    Slider(value: Binding(get: { Double(contextCount) }, set: { contextCount = Int32($0) }), in: 2...30, step: 1)
                    HStack {
                        Text("AutoPilot.Delay".i18n(lang))
                        Spacer()
                        Text(String(format: "%.1fs", typingDelay)).foregroundColor(.secondary)
                    }
                    Slider(value: $typingDelay, in: 0.5...10, step: 0.5)
                }
                Section("AutoPilot.Hours") {
                    Toggle("AutoPilot.HoursToggle".i18n(lang), isOn: $activeHours)
                    if activeHours {
                        HStack {
                            Text("AutoPilot.HoursStart".i18n(lang))
                            Spacer()
                            Text("\(hourStart):00").foregroundColor(.secondary)
                        }
                        Slider(value: Binding(get: { Double(hourStart) }, set: { hourStart = Int32($0) }), in: 0...23, step: 1)
                        HStack {
                            Text("AutoPilot.HoursEnd".i18n(lang))
                            Spacer()
                            Text("\(hourEnd):00").foregroundColor(.secondary)
                        }
                        Slider(value: Binding(get: { Double(hourEnd) }, set: { hourEnd = Int32($0) }), in: 0...24, step: 1)
                    }
                }
                Section {
                    Button("Common.Save".i18n(lang)) {
                        guard let peerId = Int64(peerIdText), peerId != 0 else {
                            onDone(nil)
                            dismiss()
                            return
                        }
                        let config = SGAutoPilotChatConfig(
                            peerId: peerId,
                            systemPrompt: systemPrompt,
                            contextMessageCount: contextCount,
                            typingDelaySeconds: typingDelay,
                            activeHoursEnabled: activeHours,
                            activeHourStart: hourStart,
                            activeHourEnd: hourEnd,
                            enabled: enabled
                        )
                        onDone(config)
                        dismiss()
                    }
                    .disabled(Int64(peerIdText) == nil || Int64(peerIdText) == 0)
                }
            }
            .navigationTitle("AutoPilot.Edit".i18n(lang))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Common.Cancel".i18n(lang)) {
                        onDone(nil)
                        dismiss()
                    }
                }
            }
    }
}
