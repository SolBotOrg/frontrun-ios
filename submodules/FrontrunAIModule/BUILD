load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FrontrunAIModule",
    module_name = "FrontrunAIModule",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
    ],
    visibility = [
        "//visibility:public",
    ],
)
