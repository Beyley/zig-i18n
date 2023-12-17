const std = @import("std");
// const i18n = @import("i18n");
const builtin = @import("builtin");

const c = @cImport(@cInclude("locale.h"));

extern "kernel32" fn GetThreadLocale() u32;
extern "kernel32" fn LCIDToLocaleName(
    locale: u32,
    name: [*c]u16,
    cchName: i32,
    dwFlags: std.os.windows.DWORD,
) i32;
extern "kernel32" fn GetLocaleInfoEx(
    locale_name: std.os.windows.LPCWSTR,
    lc_type: std.os.windows.DWORD,
    lpLCData: std.os.windows.LPWSTR,
    cchData: i32,
) i32;

pub fn getCurrentLocale(allocator: std.mem.Allocator) !?[]const u8 {
    _ = c.setlocale(c.LC_ALL, "");

    const locale = blk: {
        if (builtin.os.tag == .windows) {
            const win_c = @cImport({
                @cDefine("WIN32_LEAN_AND_MEAN", "1");
                @cInclude("windows.h");
            });

            const win_locale = GetThreadLocale();

            var name = std.mem.zeroes([85:0]u16);
            if (LCIDToLocaleName(win_locale, &name, 85, 0) == 0) {
                return null;
            }

            var parent_name = std.mem.zeroes([85:0]u16);
            if (GetLocaleInfoEx(&name, win_c.LOCALE_SPARENT, &parent_name, 85) == 0) {
                return null;
            }

            break :blk try std.unicode.utf16leToUtf8Alloc(allocator, std.mem.sliceTo(if (parent_name[0] == 0) &name else &parent_name, 0));
        } else {
            break :blk try allocator.dupe(
                u8,
                std.mem.sliceTo(c.setlocale(c.LC_ALL, null) orelse return error.UnableToGetLocale, 0),
            );
        }
    };
    defer allocator.free(locale);

    std.debug.print("got locale of {s}\n", .{locale});

    var tok = std.mem.tokenizeAny(u8, locale, "._@");

    const lang = tok.next() orelse return error.UnableToParseLocale;

    return try allocator.dupe(u8, lang);

    // return i18n.LanguageCode.fromIso639_1(lang) orelse i18n.LanguageCode.fromIso639_2(lang);

    // var code =
}
