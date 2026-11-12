import Foundation
import SwiftUI
import SGSwiftUI
import SGStrings
import AccountContext
import TelegramPresentationData

public func sgAIChatRootController(context: AccountContext, presentationData: PresentationData? = nil) -> ViewController {
    let presentationData = presentationData ?? context.sharedContext.currentPresentationData.with { $0 }
    return SGSwiftUIController(
        title: "Settings.AI.Title".i18n(presentationData.strings.baseLanguageCode),
        presentationData: presentationData,
        presentationDataSignal: context.sharedContext.presentationData
    ) {
        SGAIProviderListView()
    }
}

public func sgAIChatController(context: AccountContext, presentationData: PresentationData? = nil) -> ViewController {
    let presentationData = presentationData ?? context.sharedContext.currentPresentationData.with { $0 }
    return SGSwiftUIController(
        title: "Settings.AI.Chat".i18n(presentationData.strings.baseLanguageCode),
        presentationData: presentationData,
        presentationDataSignal: context.sharedContext.presentationData
    ) {
        SGAIChatView()
    }
}
