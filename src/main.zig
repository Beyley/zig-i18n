const std = @import("std");
const i18n = @import("i18n");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("MEMORY LEAK");

    const allocator = gpa.allocator();

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    var localization = i18n{};
    try localization.detectSystemLocale(allocator);

    std.debug.print("detected system locale of {s}\n", .{@tagName(localization.current_language)});

    localization.current_language = .eng;
    try writer.print("{s}\n", .{localization.getString(.greeting)});
    try localization.format(writer, .format, .{"John"});
    try writer.writeByte('\n');
    localization.current_language = .tok;
    try writer.print("{s}\n", .{localization.getString(.greeting)});
    try localization.format(writer, .format, .{"John"});
    try writer.writeByte('\n');
    localization.current_language = .epo;
    try writer.print("{s}\n", .{localization.getString(.greeting)});
    try localization.format(writer, .format, .{"John"});
    try writer.writeByte('\n');
}
