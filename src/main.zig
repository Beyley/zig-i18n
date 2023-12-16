const std = @import("std");
const i18n = @import("i18n");

pub fn main() !void {
    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    var localization = i18n{};
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
