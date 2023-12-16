const std = @import("std");
const i18n = @import("i18n");

pub fn main() !void {
    var localization = i18n{};
    std.debug.print("{s}\n", .{localization.getString(.greeting)});
    localization.current_language = .tok;
    std.debug.print("{s}\n", .{localization.getString(.greeting)});
    localization.current_language = .epo;
    std.debug.print("{s}\n", .{localization.getString(.greeting)});
}
