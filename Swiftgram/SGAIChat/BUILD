load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SGAIChat",
    module_name = "SGAIChat",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//Swiftgram/SGSwiftUI:SGSwiftUI",
        "//Swiftgram/SGStrings:SGStrings",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
