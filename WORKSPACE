workspace(name = "launchpad")

# To change to a version of protoc compatible with tensorflow:
#  1. Convert the required header version to a version string, e.g.:
#     3011004 => "3.11.4"
#  2. Calculate the sha256 of the binary:
#     PROTOC_VERSION="3.11.4"
#     curl -L "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip" | sha256sum
#  3. Update the two variables below.
#

PROTOC_VERSION = "21.0"
PROTOC_SHA256 = "a2a92003da7b8c0c08aab530a3c1967d377c2777723482adb9d2eb38c87a9d5f"
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

load(
    "//launchpad:repo.bzl",
    "absl_deps",
    "cc_tf_configure",
    "googletest_deps",
    "github_apple_deps",
    "github_grpc_deps",
    "protoc_deps",
    "python_deps",
)

googletest_deps()

absl_deps()
http_archive(
  name = "pybind11_abseil",
  strip_prefix = "pybind11_abseil-2c4932ed6f6204f1656e245838f4f5eae69d2e29",
  # sha256 = "be5da399b4f62615fdc2a236674638480118f6030d7b16645c6d3f0e208a7f8f",
  urls = ["https://github.com/pybind/pybind11_abseil/archive/2c4932ed6f6204f1656e245838f4f5eae69d2e29.zip"],
)

http_archive(
  name = "pybind11_bazel",
  strip_prefix = "pybind11_bazel-26973c0ff320cb4b39e45bc3e4297b82bc3a6c09",
  sha256 = "8f546c03bdd55d0e88cb491ddfbabe5aeb087f87de2fbf441391d70483affe39",
  urls = ["https://github.com/pybind/pybind11_bazel/archive/26973c0ff320cb4b39e45bc3e4297b82bc3a6c09.tar.gz"],
)

github_apple_deps()

## Begin GRPC related deps
github_grpc_deps()
load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")

grpc_deps()

load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")

grpc_extra_deps()


load("@upb//bazel:workspace_deps.bzl", "upb_deps")

upb_deps()

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()
## End GRPC related deps

cc_tf_configure()

python_deps()

protoc_deps(version = PROTOC_VERSION, sha256 = PROTOC_SHA256)

http_archive(
    name = "hedron_compile_commands",
    # Replace the commit hash in both places (below) with the latest, rather than using the stale one here.
    # Even better, set up Renovate and let it do the work for you (see "Suggestion: Updates" in the README).
    url = "https://github.com/hedronvision/bazel-compile-commands-extractor/archive/ed994039a951b736091776d677f324b3903ef939.tar.gz",
    strip_prefix = "bazel-compile-commands-extractor-ed994039a951b736091776d677f324b3903ef939",
    # When you first run this tool, it'll recommend a sha256 hash to put here with a message like: "DEBUG: Rule 'hedron_compile_commands' indicated that a canonical reproducible form can be obtained by modifying arguments sha256 = ..."
)
load("@hedron_compile_commands//:workspace_setup.bzl", "hedron_compile_commands_setup")
hedron_compile_commands_setup()