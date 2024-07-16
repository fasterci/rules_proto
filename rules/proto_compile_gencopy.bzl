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
        for [rel, f] in info.output_file_map.items():
            dsts.append(rel)
            srcs.append(f.short_path)
            runfiles.append(f)

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
        srcs = attr.label_list(
            doc = "The source files",
            allow_files = True,
        ),
    ),
    executable = True,
    test = is_test,
)

def _proto_compile_gencopy_test_impl(ctx):
    config = gencopy_config(ctx)

    runfiles = []

    # comprehend a mapping of relpath -> File
    srcfiles = {f.short_path[len(ctx.label.package):].lstrip("/"): f for f in ctx.files.srcs}

    for info in [dep[ProtoCompileInfo] for dep in ctx.attr.deps]:
        runfiles += info.output_file_map.values()
        srcfiles = info.output_file_map

        srcs = []  # list of string
        for f in info.outputs:
            if config.mode == "check":
                # if we are in 'check' mode, the src and dst cannot be the same
                # file, so make a copy of it...  but first, we need to find it
                # in the srcs files!
                found = False
                for srcfilename, srcfile in srcfiles.items():
                    if srcfilename == f.basename:
                        replica = ctx.actions.declare_file(f.basename + ".actual", sibling = f)
                        _copy_file(ctx.actions, srcfile, replica)
                        runfiles.append(replica)
                        srcs.append(replica.short_path)
                        found = True
                        break
                    elif srcfilename == f.basename + ctx.attr.extension:
                        runfiles.append(srcfile)
                        srcs.append(srcfile.short_path)
                        found = True
                        break
                if not found:
                    fail("could not find matching source file for generated file %s in %r" % (f.basename, srcfiles))

            else:
                srcs.append(f.short_path)

        config.packageConfigs.append(
            struct(
                targetLabel = str(info.label),
                targetPackage = info.label.package,
                targetWorkspaceRoot = info.label.workspace_root,
                generatedFiles = [f.short_path for f in info.outputs],
                sourceFiles = srcs,
            ),
        )

    config_json, script, runfiles = gencopy_action(ctx, config, runfiles)

    return [DefaultInfo(
        files = depset([config_json]),
        runfiles = runfiles,
        executable = script,
    )]

proto_compile_gencopy_rule_test = rule(
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
        extension = attr.string(
            doc = "optional file extension to add to the copied file",
            mandatory = False,
        ),
    ),
    executable = True,
    test = True,
)
