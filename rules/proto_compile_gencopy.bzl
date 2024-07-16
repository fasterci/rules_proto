"""proto_compile_gencopy.bzl provides the proto_compile_gencopy_run and proto_compile_gencopy_test rules.
"""

load("//cmd/gencopy:gencopy.bzl", "gencopy_action", "gencopy_attrs", "gencopy_config")
load(":providers.bzl", "ProtoCompileInfo")

def _copy_file(actions, src, dst):
    """Copy a file to a new path destination

    Args:
      actions: the <ctx.actions> object
      src: the source file <File>
      dst: the destination path of the file
    Returns:
      <Generated File> for the copied file
    """
    actions.run_shell(
        mnemonic = "CopyFile",
        inputs = [src],
        outputs = [dst],
        command = "cp '{}' '{}'".format(src.path, dst.path),
        progress_message = "copying {} to {}".format(src.path, dst.path),
    )

def _proto_compile_gencopy_run_impl(ctx):
    config = gencopy_config(ctx)

    runfiles = []
    for info in [dep[ProtoCompileInfo] for dep in ctx.attr.deps]:
        srcs = []
        dsts = []
        for [rel, generated_file] in info.output_file_map.items():
            runfiles.append(generated_file)
            srcs.append(generated_file.short_path)
            dsts.append(rel)

        config.packageConfigs.append(
            struct(
                targetLabel = str(info.label),
                targetPackage = info.label.package,
                targetWorkspaceRoot = info.label.workspace_root,
                generatedFiles = dsts,
                sourceFiles = srcs,
            ),
        )

    config_json, script, runfiles = gencopy_action(ctx, config, runfiles)

    return [DefaultInfo(
        files = depset([config_json]),
        runfiles = runfiles,
        executable = script,
    )]

proto_compile_gencopy_run = rule(
    implementation = _proto_compile_gencopy_run_impl,
    attrs = dict(
        gencopy_attrs,
        deps = attr.label_list(
            doc = "The ProtoCompileInfo providers",
            providers = [ProtoCompileInfo],
        ),
    ),
    executable = True,
    test = False,
)

def _proto_compile_gencopy_test_impl(ctx):
    config = gencopy_config(ctx)

    runfiles = []

    source_file_map = {f.short_path: f for f in ctx.files.srcs}

    for info in [dep[ProtoCompileInfo] for dep in ctx.attr.deps]:
        srcs = []
        dsts = []
        for [rel, generated_file] in info.output_file_map.items():
            source_file = source_file_map.get(rel)
            if not source_file:
                fail("could not find matching source file for generated file %s in %r" % (rel, source_file_map.keys()))

            if source_file.short_path == generated_file.short_path:
                fail("source file path must be distinct from generated file path (src=%s, dst=%s)" % (source_file.short_path, generated_file.short_path))

            runfiles.append(source_file)
            runfiles.append(generated_file)
            srcs.append(source_file.short_path)
            dsts.append(generated_file.short_path)

        config.packageConfigs.append(
            struct(
                targetLabel = str(info.label),
                targetPackage = info.label.package,
                targetWorkspaceRoot = info.label.workspace_root,
                generatedFiles = dsts,
                sourceFiles = srcs,
            ),
        )

    config_json, script, runfiles = gencopy_action(ctx, config, runfiles)

    return [DefaultInfo(
        files = depset([config_json]),
        runfiles = runfiles,
        executable = script,
    )]

proto_compile_gencopy_test = rule(
    implementation = _proto_compile_gencopy_test_impl,
    attrs = dict(
        gencopy_attrs,
        deps = attr.label_list(
            doc = "The ProtoCompileInfo providers",
            providers = [ProtoCompileInfo],
        ),
        srcs = attr.label_list(
            doc = "The source files",
            allow_files = True,
        ),
    ),
    executable = True,
    test = True,
)

# found = False
# for srcfilename, srcfile in srcfiles.items():
#     if srcfilename == f.basename:
#         replica = ctx.actions.declare_file(f.basename + ".actual", sibling = f)
#         _copy_file(ctx.actions, srcfile, replica)
#         runfiles.append(replica)
#         srcs.append(replica.short_path)
#         found = True
#         break
#     elif srcfilename == f.basename + ctx.attr.extension:
#         runfiles.append(srcfile)
#         srcs.append(srcfile.short_path)
#         found = True
#         break
# if not found:
#     fail("could not find matching source file for generated file %s in %r" % (f.basename, srcfiles))
