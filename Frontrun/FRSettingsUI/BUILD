load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRSettingsUI",
    module_name = "FRSettingsUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        # Frontrun modules
        "//Frontrun/FRServices:FRServices",

        # Signal kit
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",

        # Telegram context and core
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Postbox:Postbox",

        # Display
        "//submodules/Display:Display",

        # ItemList UI framework (for settings screens)
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",

        # Alert and prompt UI
        "//submodules/AlertUI:AlertUI",
        "//submodules/PromptUI:PromptUI",

        # Searchable selection (for model picker)
        "//submodules/TelegramUI/Components/SearchableSelectionScreen:SearchableSelectionScreen",
    ],
    visibility = ["//visibility:public"],
)
