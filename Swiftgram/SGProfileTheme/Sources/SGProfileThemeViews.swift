import Foundation
import SwiftUI
import SGSwiftUI
import SGStrings
import AccountContext
import Display
import TelegramPresentationData

public func sgProfileThemeController(context: AccountContext, presentationData: PresentationData? = nil) -> ViewController {
    let presentationData = presentationData ?? context.sharedContext.currentPresentationData.with { $0 }
    return SGSwiftUIController(
        title: "ProfileTheme.Title".i18n(presentationData.strings.baseLanguageCode),
        presentationData: presentationData,
        presentationDataSignal: context.sharedContext.presentationData
    ) {
        SGProfileThemeView()
    }
}

struct SGProfileThemeView: View {
    @Environment(\.lang) var lang: String
    @State private var style: SGProfileStyle = SGProfileStyleStore.shared.current
    @State private var startColor: Color = Color(SGProfileStyleStore.shared.color(from: SGProfileStyleStore.shared.current.gradientStart))
    @State private var endColor: Color = Color(SGProfileStyleStore.shared.color(from: SGProfileStyleStore.shared.current.gradientEnd))

    var body: some View {
        Form {
            Section("ProfileTheme.ProfileHeader") {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [startColor, endColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)
                        Text("Z")
                            .font(.system(size: style.nameFontSize, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ProfileTheme.PreviewName".i18n(lang))
                            .font(.system(size: style.nameFontSize, weight: .semibold))
                        Text(style.bioFontStyle == "italic" ? "ProfileTheme.PreviewBio".i18n(lang) : "ProfileTheme.PreviewBio".i18n(lang))
                            .font(style.bioFontStyle == "italic" ? .body.italic() : .body)
                            .foregroundColor(.secondary)
                    }
                }
                ColorPicker("ProfileTheme.GradientStart".i18n(lang), selection: $startColor, supportsOpacity: false)
                ColorPicker("ProfileTheme.GradientEnd".i18n(lang), selection: $endColor, supportsOpacity: false)
                HStack {
                    Text("ProfileTheme.NameSize".i18n(lang))
                    Spacer()
                    Text("\(Int(style.nameFontSize))").foregroundColor(.secondary)
                }
                Slider(value: $style.nameFontSize, in: 16...40, step: 1)
                Picker("ProfileTheme.BioStyle".i18n(lang), selection: $style.bioFontStyle) {
                    Text("ProfileTheme.BioRegular".i18n(lang)).tag("regular")
                    Text("ProfileTheme.BioItalic".i18n(lang)).tag("italic")
                }
                .pickerStyle(.segmented)
            }
            Section("ProfileTheme.Chats") {
                Toggle("ProfileTheme.HideOnline".i18n(lang), isOn: $style.hideOnlineBadge)
                Picker("ProfileTheme.BubbleStyle".i18n(lang), selection: $style.bubbleStyle) {
                    Text("ProfileTheme.BubbleClassic".i18n(lang)).tag("classic")
                    Text("ProfileTheme.BubbleRounded".i18n(lang)).tag("rounded")
                }
                .pickerStyle(.segmented)
            }
            Section {
                Button("Common.Save".i18n(lang)) {
                    let store = SGProfileStyleStore.shared
                    var updated = style
                    updated.gradientStart = store.hex(from: UIColor(startColor))
                    updated.gradientEnd = store.hex(from: UIColor(endColor))
                    store.current = updated
                }
            }
        }
        .navigationTitle("ProfileTheme.Title".i18n(lang))
    }
}
