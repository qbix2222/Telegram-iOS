load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SGAutoPilot",
    module_name = "SGAutoPilot",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//Swiftgram/SGAIChat:SGAIChat",
        "//Swiftgram/SGSwiftUI:SGSwiftUI",
        "//Swiftgram/SGStrings:SGStrings",
    ],
    visibility = [
        "//visibility:public",
    ],
)
