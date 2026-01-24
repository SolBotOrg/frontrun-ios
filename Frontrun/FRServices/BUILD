load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FRServices",
    module_name = "FRServices",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//Frontrun/FRModels:FRModels",
    ],
    visibility = ["//visibility:public"],
)
