"""Custom external dependencies."""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

# Sanitize a dependency so that it works correctly from code that includes
# codebase as a submodule.
def clean_dep(dep):
    return str(Label(dep))

def get_python_path(ctx):
    path = ctx.os.environ.get("PYTHON_BIN_PATH")
    if not path:
        fail(
            "Could not get environment variable PYTHON_BIN_PATH.  " +
            "Check your .bazelrc file.",
        )
    return path

def _find_tf_include_path(repo_ctx):
    exec_result = repo_ctx.execute(
        [
            get_python_path(repo_ctx),
            "-c",
            "import tensorflow as tf; import sys; " +
            "sys.stdout.write(tf.sysconfig.get_include())",
        ],
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("Could not locate tensorflow installation path:\n{}"
            .format(exec_result.stderr))
    return exec_result.stdout.splitlines()[-1]

def _find_tf_lib_path(repo_ctx):
    exec_result = repo_ctx.execute(
        [
            get_python_path(repo_ctx),
            "-c",
            "import tensorflow as tf; import sys; " +
            "sys.stdout.write(tf.sysconfig.get_lib())",
        ],
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("Could not locate tensorflow installation path:\n{}"
            .format(exec_result.stderr))
    return exec_result.stdout.splitlines()[-1]

def _find_numpy_include_path(repo_ctx):
    exec_result = repo_ctx.execute(
        [
            get_python_path(repo_ctx),
            "-c",
            "import numpy; import sys; " +
            "sys.stdout.write(numpy.get_include())",
        ],
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("Could not locate numpy includes path:\n{}"
            .format(exec_result.stderr))
    return exec_result.stdout.splitlines()[-1]

def _find_python_include_path(repo_ctx):
    exec_result = repo_ctx.execute(
        [
            get_python_path(repo_ctx),
            "-c",
            "from distutils import sysconfig; import sys; " +
            "sys.stdout.write(sysconfig.get_python_inc())",
        ],
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("Could not locate python includes path:\n{}"
            .format(exec_result.stderr))
    return exec_result.stdout.splitlines()[-1]

def _find_python_solib_path(repo_ctx):
    exec_result = repo_ctx.execute(
        [
            get_python_path(repo_ctx),
            "-c",
            "import sys; vi = sys.version_info; " +
            "sys.stdout.write('python{}.{}'.format(vi.major, vi.minor))",
        ],
    )
    if exec_result.return_code != 0:
        fail("Could not locate python shared library path:\n{}"
            .format(exec_result.stderr))
    version = exec_result.stdout.splitlines()[-1]
    basename = "lib{}.so".format(version)
    exec_result = repo_ctx.execute(
        ["{}-config".format(version), "--configdir"],
        quiet = True,
    )
    if exec_result.return_code != 0:
        fail("Could not locate python shared library path:\n{}"
            .format(exec_result.stderr))
    solib_dir = exec_result.stdout.splitlines()[-1]
    full_path = repo_ctx.path("{}/{}".format(solib_dir, basename))
    if not full_path.exists:
        fail("Unable to find python shared library file:\n{}/{}"
            .format(solib_dir, basename))
    return struct(dir = solib_dir, basename = basename)

def _eigen_archive_repo_impl(repo_ctx):
    tf_include_path = _find_tf_include_path(repo_ctx)
    repo_ctx.symlink(tf_include_path, "tf_includes")
    repo_ctx.file(
        "BUILD",
        content = """
cc_library(
    name = "includes",
    hdrs = glob(["tf_includes/Eigen/**/*.h",
                 "tf_includes/Eigen/**",
                 "tf_includes/unsupported/Eigen/**/*.h",
                 "tf_includes/unsupported/Eigen/**"]),
    # https://groups.google.com/forum/#!topic/bazel-discuss/HyyuuqTxKok
    includes = ["tf_includes"],
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

def _nsync_includes_repo_impl(repo_ctx):
    tf_include_path = _find_tf_include_path(repo_ctx)
    repo_ctx.symlink(tf_include_path + "/external", "nsync_includes")
    repo_ctx.file(
        "BUILD",
        content = """
cc_library(
    name = "includes",
    hdrs = glob(["nsync_includes/nsync/public/*.h"]),
    includes = ["nsync_includes"],
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

def _zlib_includes_repo_impl(repo_ctx):
    tf_include_path = _find_tf_include_path(repo_ctx)
    repo_ctx.symlink(
        tf_include_path + "/external/zlib",
        "zlib",
    )
    repo_ctx.file(
        "BUILD",
        content = """
cc_library(
    name = "includes",
    hdrs = glob(["zlib/**/*.h"]),
    includes = ["zlib"],
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

def _snappy_includes_repo_impl(repo_ctx):
    tf_include_path = _find_tf_include_path(repo_ctx)
    repo_ctx.symlink(
        tf_include_path + "/external/snappy",
        "snappy",
    )
    repo_ctx.file(
        "BUILD",
        content = """
cc_library(
    name = "includes",
    hdrs = glob(["snappy/*.h"]),
    includes = ["snappy"],
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

def _protobuf_includes_repo_impl(repo_ctx):
    tf_include_path = _find_tf_include_path(repo_ctx)
    repo_ctx.symlink(tf_include_path, "tf_includes")
    repo_ctx.symlink(Label("//third_party:protobuf.BUILD"), "BUILD")

def _tensorflow_includes_repo_impl(repo_ctx):
    tf_include_path = _find_tf_include_path(repo_ctx)
    repo_ctx.symlink(tf_include_path, "tensorflow_includes")
    repo_ctx.file(
        "BUILD",
        content = """
cc_library(
    name = "includes",
    hdrs = glob(
        [
            "tensorflow_includes/**/*.h",
            "tensorflow_includes/third_party/eigen3/**",
        ],
        exclude = ["tensorflow_includes/absl/**/*.h"],
    ),
    includes = ["tensorflow_includes"],
    deps = [
        "@com_google_absl//absl/container:flat_hash_map",
        "@com_google_absl//absl/status:statusor",
        "@eigen_archive//:includes",
        "@protobuf_archive//:includes",
        "@zlib_includes//:includes",
        "@snappy_includes//:includes",
    ],
    visibility = ["//visibility:public"],
)
filegroup(
    name = "protos",
    srcs = glob(["tensorflow_includes/**/*.proto"]),
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

def _tensorflow_solib_repo_impl(repo_ctx):
    tf_lib_path = _find_tf_lib_path(repo_ctx)
    repo_ctx.symlink(tf_lib_path, "tensorflow_solib")
    repo_ctx.file(
        "BUILD",
        content = """
cc_library(
    name = "framework_lib",
    srcs = ["tensorflow_solib/libtensorflow_framework.so.2"],
    deps = ["@python_includes", "@python_includes//:numpy_includes"],
    visibility = ["//visibility:public"],
)
""",
    )

def _python_includes_repo_impl(repo_ctx):
    python_include_path = _find_python_include_path(repo_ctx)
    # python_solib = _find_python_solib_path(repo_ctx)
    repo_ctx.symlink(python_include_path, "python_includes")
    numpy_include_path = _find_numpy_include_path(repo_ctx)
    repo_ctx.symlink(numpy_include_path, "numpy_includes")
    # repo_ctx.symlink(
    #     "{}/{}".format(python_solib.dir, python_solib.basename),
    #     python_solib.basename,
    # )

    repo_ctx.file(
        "BUILD",
        content = """
cc_library(
    name = "python_includes",
    hdrs = glob(["python_includes/**/*.h"]),
    includes = ["python_includes"],
    visibility = ["//visibility:public"],
)
cc_library(
    name = "numpy_includes",
    hdrs = glob(["numpy_includes/**/*.h"]),
    includes = ["numpy_includes"],
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

def cc_tf_configure():
    """Autoconf pre-installed tensorflow repo."""
    make_eigen_repo = repository_rule(implementation = _eigen_archive_repo_impl)
    make_eigen_repo(name = "eigen_archive")
    make_nsync_repo = repository_rule(
        implementation = _nsync_includes_repo_impl,
    )
    make_nsync_repo(name = "nsync_includes")
    make_zlib_repo = repository_rule(
        implementation = _zlib_includes_repo_impl,
    )
    make_zlib_repo(name = "zlib_includes")
    make_snappy_repo = repository_rule(
        implementation = _snappy_includes_repo_impl,
    )
    make_snappy_repo(name = "snappy_includes")
    make_protobuf_repo = repository_rule(
        implementation = _protobuf_includes_repo_impl,
    )
    make_protobuf_repo(name = "protobuf_archive")
    make_tfinc_repo = repository_rule(
        implementation = _tensorflow_includes_repo_impl,
    )
    make_tfinc_repo(name = "tensorflow_includes")
    make_tflib_repo = repository_rule(
        implementation = _tensorflow_solib_repo_impl,
    )
    make_tflib_repo(name = "tensorflow_solib")
    make_python_inc_repo = repository_rule(
        implementation = _python_includes_repo_impl,
    )
    make_python_inc_repo(name = "python_includes")

def python_deps():
    http_archive(
        name = "pybind11",
        urls = [
            "https://storage.googleapis.com/mirror.tensorflow.org/github.com/pybind/pybind11/archive/v2.10.4.tar.gz",
            "https://github.com/pybind/pybind11/archive/v2.10.4.tar.gz",
        ],
        # sha256 = "eacf582fa8f696227988d08cfc46121770823839fe9e301a20fbce67e7cd70ec",
        strip_prefix = "pybind11-2.10.4",
        build_file = clean_dep("//third_party:pybind11.BUILD"),
    )

    http_archive(
        name = "absl_py",
        sha256 = "a7c51b2a0aa6357a9cbb2d9437e8cd787200531867dc02565218930b6a32166e",
        strip_prefix = "abseil-py-pypi-v1.0.0",
        urls = [
            "https://storage.googleapis.com/mirror.tensorflow.org/github.com/abseil/abseil-py/archive/refs/tags/v1.0.0.tar.gz",
            "https://github.com/abseil/abseil-py/archive/refs/tags/v1.0.0.tar.gz",
        ],
    )

def github_apple_deps():
    http_archive(
        name = "build_bazel_rules_apple",
        sha256 = "36072d4f3614d309d6a703da0dfe48684ec4c65a89611aeb9590b45af7a3e592",
        urls = ["https://github.com/bazelbuild/rules_apple/releases/download/1.0.1/rules_apple.1.0.1.tar.gz"],
    )
    http_archive(
        name = "build_bazel_apple_support",
        sha256 = "ce1042cf936540eaa7b49c4549d7cd9b6b1492acbb6e765840a67a34b8e17a97",
        urls = ["https://github.com/bazelbuild/apple_support/releases/download/1.1.0/apple_support.1.1.0.tar.gz"],
    )

def github_grpc_deps():
    http_archive(
        name = "io_bazel_rules_go",
        sha256 = "16e9fca53ed6bd4ff4ad76facc9b7b651a89db1689a2877d6fd7b82aa824e366",
        urls = ["https://github.com/bazelbuild/rules_go/releases/download/v0.34.0/rules_go-v0.34.0.zip"],
    )
    http_archive(
        name = "upb",
        # sha256 = "61d0417abd60e65ed589c9deee7c124fe76a4106831f6ad39464e1525cef1454",
        strip_prefix = "upb-9effcbcb27f0a665f9f345030188c0b291e32482",
        patches = ["//third_party:upb_platform_fix.patch"],
        patch_args = ["-p1"],
        urls = ["https://github.com/protocolbuffers/upb/archive/9effcbcb27f0a665f9f345030188c0b291e32482.tar.gz"],
    )

    http_archive(
        name = "com_github_grpc_grpc",
        strip_prefix = "grpc-b54a5b338637f92bfcf4b0bc05e0f57a5fd8fadd",
        # sha256 = "3c305f0ca5f98919bc104448f59177e7b936acd5c69c144bf4a548cad723e1e4",
        patches = [
            "//third_party:generate_cc_env_fix.patch",
            "//third_party:register_go_toolchain.patch",
        ],
        patch_args = ["-p1"],
        urls = [
            "https://github.com/grpc/grpc/archive/b54a5b338637f92bfcf4b0bc05e0f57a5fd8fadd.tar.gz"
        ],
    )

def googletest_deps():
    http_archive(
        name = "com_google_googletest",
        sha256 = "ff7a82736e158c077e76188232eac77913a15dac0b22508c390ab3f88e6d6d86",
        strip_prefix = "googletest-b6cd405286ed8635ece71c72f118e659f4ade3fb",
        urls = [
            "https://storage.googleapis.com/mirror.tensorflow.org/github.com/google/googletest/archive/b6cd405286ed8635ece71c72f118e659f4ade3fb.zip",
            "https://github.com/google/googletest/archive/b6cd405286ed8635ece71c72f118e659f4ade3fb.zip",
        ],
    )

def absl_deps():
    http_archive(
        name = "com_google_absl",
        sha256 = "8eeec9382fc0338ef5c60053f3a4b0e0708361375fe51c9e65d0ce46ccfe55a7",  # SHARED_ABSL_SHA
        strip_prefix = "abseil-cpp-b971ac5250ea8de900eae9f95e06548d14cd95fe",
        urls = [
            # "https://storage.googleapis.com/mirror.tensorflow.org/github.com/abseil/abseil-cpp/archive/b971ac5250ea8de900eae9f95e06548d14cd95fe.tar.gz",
            "https://github.com/abseil/abseil-cpp/archive/b971ac5250ea8de900eae9f95e06548d14cd95fe.tar.gz",
        ],
    )

def _protoc_archive(ctx):
    version = ctx.attr.version
    sha256 = ctx.attr.sha256

    urls = [
        "https://github.com/protocolbuffers/protobuf/releases/download/v%s/protoc-%s-linux-x86_64.zip" % (version, version),
    ]
    ctx.download_and_extract(
        url = urls,
        sha256 = sha256,
    )

    ctx.file(
        "BUILD",
        content = """
filegroup(
    name = "protoc_bin",
    srcs = ["bin/protoc"],
    visibility = ["//visibility:public"],
)
""",
        executable = False,
    )

protoc_archive = repository_rule(
    implementation = _protoc_archive,
    attrs = {
        "version": attr.string(mandatory = True),
        "sha256": attr.string(mandatory = True),
    },
)

def protoc_deps(version, sha256):
    protoc_archive(name = "protobuf_protoc", version = version, sha256 = sha256)
