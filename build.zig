const std = @import("std");

const language_names_index_url = "https://iso639-3.sil.org/sites/iso639-3/files/downloads/iso-639-3_Name_Index.tab";

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = try setupI18NModule(
        b,
        "eng",
        &.{
            .{
                .code = "tok",
                .path = b.pathFromRoot("trans/tok.po"),
            },
            .{
                .code = "eng",
                .path = b.pathFromRoot("trans/eng.po"),
            },
            .{
                .code = "epo",
                .path = b.pathFromRoot("trans/epo.po"),
            },
        },
    );

    const exe = b.addExecutable(.{
        .name = "zig-i18n",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("i18n", mod);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn setupI18NModule(
    b: *std.Build,
    default_language: []const u8,
    localization_files: []const struct {
        code: []const u8,
        path: []const u8,
    },
) !*std.build.Module {
    const language_names_index_path = try b.cache_root.join(b.allocator, &.{"iso-639-3-language-names-index.tab"});

    var client = std.http.Client{
        .allocator = b.allocator,
    };
    defer client.deinit();

    const language_names_index_file = std.fs.openFileAbsolute(language_names_index_path, .{}) catch |err| blk: {
        if (err == std.fs.File.OpenError.FileNotFound) {
            const f = try std.fs.createFileAbsolute(language_names_index_path, .{ .read = true });

            var res = try client.fetch(b.allocator, .{
                .location = .{ .url = language_names_index_url },
            });
            defer res.deinit();

            try f.writeAll(res.body.?);

            try f.seekTo(0);

            break :blk f;
        }

        return err;
    };
    defer language_names_index_file.close();

    const generator = b.addExecutable(.{
        .name = "i18n-gen",
        .root_source_file = .{ .path = "src/gen.zig" },
    });

    var run_step = b.addRunArtifact(generator);
    run_step.addFileArg(.{ .path = language_names_index_path });
    const generated_file = run_step.addOutputFileArg("i18n.zig");
    run_step.addArg(default_language);
    for (localization_files) |localization_file| {
        run_step.addArg(localization_file.code);
        run_step.addFileArg(.{ .path = localization_file.path });
    }

    const module = b.createModule(.{ .source_file = generated_file });

    return module;
}
