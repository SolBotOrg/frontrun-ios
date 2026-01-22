load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SearchableSelectionScreen",
    module_name = "SearchableSelectionScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ItemListUI",
        "//submodules/PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
