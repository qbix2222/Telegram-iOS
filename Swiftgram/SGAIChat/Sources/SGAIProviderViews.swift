import Foundation
import SwiftUI
import SGSwiftUI
import SGStrings
import AccountContext
import Display
import TelegramPresentationData

struct SGAIProviderListView: View {
    @Environment(\.lang) var lang: String
    @State private var providers: [SGAIProvider] = SGAIProviderStore.shared.all
    @State private var activeIndex: Int = SGAIProviderStore.shared.activeIndexValue()
    @State private var editingProvider: SGAIProvider?
    @State private var editingIndex: Int?
    @State private var showAdd = false

    var body: some View {
        List {
            Section {
                ForEach(Array(providers.enumerated()), id: \.offset) { index, provider in
                    Button {
                        SGAIProviderStore.shared.activate(index)
                        activeIndex = index
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(provider.name).font(.body)
                                Text(provider.model.isEmpty ? "Settings.AI.NoModel".i18n(lang) : provider.model)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if index == activeIndex {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            SGAIProviderStore.shared.remove(at: index)
                            providers = SGAIProviderStore.shared.all
                            activeIndex = SGAIProviderStore.shared.activeIndexValue()
                        } label: {
                            Label("Common.Delete".i18n(lang), systemImage: "trash")
                        }
                        Button {
                            editingProvider = provider
                            editingIndex = index
                        } label: {
                            Label("Common.Edit".i18n(lang), systemImage: "pencil")
                        }
                    }
                }
            } header: {
                Text("Settings.AI.Providers".i18n(lang))
            } footer: {
                Text("Settings.AI.Footer".i18n(lang))
            }

            Section {
                Button {
                    editingProvider = SGAIProvider(name: "", endpoint: "", apiKey: "", model: "", systemPrompt: "", temperature: 0.7)
                    editingIndex = nil
                } label: {
                    Label("Settings.AI.AddProvider".i18n(lang), systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Settings.AI.Title".i18n(lang))
        .sheet(isPresented: Binding(get: { editingProvider != nil }, set: { if !$0 { editingProvider = nil } })) {
            if let provider = editingProvider {
                SGAIProviderEditView(provider: provider, index: editingIndex) {
                    providers = SGAIProviderStore.shared.all
                    activeIndex = SGAIProviderStore.shared.activeIndexValue()
                    editingProvider = nil
                }
            }
        }
    }
}

struct SGAIProviderEditView: View {
    @Environment(\.lang) var lang: String
    @State var provider: SGAIProvider
    let index: Int?
    let onDone: () -> Void

    @State private var models: [SGAIModel] = []
    @State private var loadingModels = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Settings.AI.Name".i18n(lang)) {
                    TextField("Settings.AI.NamePlaceholder".i18n(lang), text: $provider.name)
                }
                Section("Settings.AI.Endpoint".i18n(lang)) {
                    TextField("https://api.openai.com/v1", text: $provider.endpoint)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    TextField("Settings.AI.ApiKey".i18n(lang), text: $provider.apiKey)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                    Button {
                        loadModels()
                    } label: {
                        if loadingModels {
                            ProgressView()
                        } else {
                            Label("Settings.AI.LoadModels".i18n(lang), systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(provider.endpoint.isEmpty || loadingModels)
                }
                Section("Settings.AI.Model".i18n(lang)) {
                    if !models.isEmpty {
                        ForEach(models, id: \.id) { model in
                            Button {
                                provider.model = model.id
                            } label: {
                                HStack {
                                    Text(model.id).font(.callout)
                                    Spacer()
                                    if model.id == provider.model {
                                        Image(systemName: "checkmark").foregroundColor(.accentColor)
                                    }
                                }
                            }
                        }
                    } else {
                        TextField("gpt-4o-mini", text: $provider.model)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                    }
                }
                Section("Settings.AI.SystemPrompt".i18n(lang)) {
                    TextEditor(text: $provider.systemPrompt)
                        .frame(minHeight: 80)
                        .autocorrectionDisabled()
                }
                Section("Settings.AI.Temperature".i18n(lang)) {
                    Slider(value: $provider.temperature, in: 0...2, step: 0.1)
                    Text(String(format: "%.1f", provider.temperature)).font(.caption).foregroundColor(.secondary)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
            }
            .navigationTitle(index == nil ? "Settings.AI.AddProvider".i18n(lang) : "Common.Edit".i18n(lang))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Common.Cancel".i18n(lang)) { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Common.Save".i18n(lang)) {
                        var trimmed = provider
                        trimmed.endpoint = trimmed.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
                        SGAIProviderStore.shared.save(trimmed, at: index)
                        onDone()
                    }
                    .disabled(provider.name.isEmpty || provider.endpoint.isEmpty)
                }
            }
        }
    }

    private func loadModels() {
        loadingModels = true
        errorMessage = nil
        SGAIClient.shared.fetchModels(endpoint: provider.endpoint, apiKey: provider.apiKey) { result in
            DispatchQueue.main.async {
                loadingModels = false
                switch result {
                case .success(let list):
                    models = list
                    if list.isEmpty { errorMessage = "Settings.AI.NoModels".i18n(lang) }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
