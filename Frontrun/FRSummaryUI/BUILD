load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRSummaryUI",
    module_name = "FRSummaryUI",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        # Frontrun modules
        "//Frontrun/FRServices:FRServices",
        "//Frontrun/FRModels:FRModels",

        # Signal kit
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",

        # Telegram context and core
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/Postbox:Postbox",

        # Display and AsyncDisplayKit
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",

        # Component framework
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ViewControllerComponent:ViewControllerComponent",
        "//submodules/Components/SheetComponent:SheetComponent",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Markdown:Markdown",

        # UI components used
        "//Frontrun/FRSettingsUI:FRSettingsUI",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent:GlassBarButtonComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/ContextUI:ContextUI",
        "//submodules/UndoUI:UndoUI",
    ],
    visibility = ["//visibility:public"],
)
