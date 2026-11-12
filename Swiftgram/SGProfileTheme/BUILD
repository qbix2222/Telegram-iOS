load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SGProfileTheme",
    module_name = "SGProfileTheme",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext:AccountContext",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//Swiftgram/SGSwiftUI:SGSwiftUI",
        "//Swiftgram/SGStrings:SGStrings",
    ],
    visibility = [
        "//visibility:public",
    ],
)
