const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer if(gpa.deinit() == .leak) @panic("MEMORY LEAK");

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const language_names_index_path = args[1];
    const output_path = args[2];
    const default_language = args[3];

    const language_names_index_file = try std.fs.openFileAbsolute(language_names_index_path, .{});
    defer language_names_index_file.close();
    const output_file = try std.fs.createFileAbsolute(output_path, .{});
    defer output_file.close();

    //A hashmap of language code to print name
    var language_codes = std.StringHashMap([]const u8).init(allocator);
    defer language_codes.deinit();

    var buffered_reader = std.io.bufferedReader(language_names_index_file.reader());
    var reader = buffered_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |read| {
        //Trim the newlines from the end
        const line = std.mem.trimRight(u8, read, "\r\n");

        var iter = std.mem.splitAny(u8, line, "\t");

        //Shove the language codes into the hash map
        try language_codes.put(try allocator.dupe(u8, iter.next() orelse unreachable), try allocator.dupe(u8, iter.next() orelse unreachable));
    }

    var localizations = std.StringHashMap(std.StringHashMap([]const u8)).init(allocator);
    defer localizations.deinit();

    var i: usize = 4;
    while (i < args.len) : (i += 2) {
        const code = args[i];
        const path = args[i + 1];

        if (language_codes.getKey(code) == null) return error.UnknownLanguageCode;

        var entries = std.StringHashMap([]const u8).init(allocator);

        const po_file = try std.fs.openFileAbsolute(path, .{});
        defer po_file.close();

        buffered_reader = std.io.bufferedReader(po_file.reader());
        reader = buffered_reader.reader();

        var last_id: ?[]const u8 = null;
        while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |read| {
            const line = std.mem.trim(u8, read, "\t \r\n");

            //Skip blank lines
            if (line.len == 0) continue;
            //Skip comments
            if (line[0] == '#') continue;

            //Get the index of the first space
            const first_space_pos = std.mem.indexOf(u8, line, " ") orelse return error.InvalidPoFile;

            const line_type = std.mem.trim(u8, line[0..first_space_pos], " \t\r\n");
            const line_payload = std.mem.trim(u8, line[first_space_pos..], " \t\r\n");

            if (std.mem.eql(u8, line_type, "msgid")) {
                if (last_id) |last_id_unwrapped| allocator.free(last_id_unwrapped);

                last_id = try allocator.dupe(u8, line_payload);

                continue;
            }

            if (std.mem.eql(u8, line_type, "msgstr")) {
                if (last_id) |last_id_unwrapped| {
                    try entries.put(try allocator.dupe(u8, last_id_unwrapped), try allocator.dupe(u8, line_payload));
                } else {
                    return error.MissingMsgIdLine;
                }

                continue;
            }
        }

        try localizations.put(code, entries);
    }

    var buffered_writer = std.io.bufferedWriter(output_file.writer());
    defer buffered_writer.flush() catch unreachable;
    const writer = buffered_writer.writer();

    try std.fmt.format(writer,
        \\const std = @import("std");
        \\
        \\pub const LanguageCode = enum {{
        \\{s}
        \\
        \\    ///Returns the official print name corroponding to that language
        \\    pub fn printName(self: LanguageCode) []const u8 {{
        \\    return switch(self) {{
        \\    {s}
        \\    }};
        \\    }}
        \\}};
        \\
        \\pub const LocalizationKey = enum {{
        \\{s}
        \\}};
        \\
        \\const Self = @This();
        \\
        \\current_language: LanguageCode = .@"{s}",
        \\
        \\pub fn getString(self: Self, string: LocalizationKey) []const u8 {{
        \\    return switch(self.current_language) {{
        \\{s}
        \\    }};
        \\}}
    , .{
        blk: {
            var array_list = std.ArrayList(u8).init(allocator);
            var iter = language_codes.keyIterator();
            while (iter.next()) |key| {
                if (localizations.get(key.*) != null)
                    try std.fmt.format(array_list.writer(),
                        \\    @"{s}",
                        \\
                    , .{key.*});
            }
            break :blk try array_list.toOwnedSlice();
        },
        blk: {
            var array_list = std.ArrayList(u8).init(allocator);
            var iter = language_codes.iterator();
            while (iter.next()) |entry| {
                if (localizations.get(entry.key_ptr.*) != null)
                    try std.fmt.format(array_list.writer(),
                        \\    .@"{s}" => "{s}",
                        \\
                    , .{ entry.key_ptr.*, entry.value_ptr.* });
            }
            break :blk try array_list.toOwnedSlice();
        },
        blk: {
            var array_list = std.ArrayList(u8).init(allocator);
            const strings: std.StringHashMap([]const u8) = localizations.get(default_language) orelse return error.DefaultLanguageMissingLocalizations;
            var iter = strings.keyIterator();
            while (iter.next()) |key| {
                try std.fmt.format(array_list.writer(),
                    \\    @"{s}",
                    \\
                , .{key.*});
            }
            break :blk try array_list.toOwnedSlice();
        },
        default_language,
        blk: {
            var array_list = std.ArrayList(u8).init(allocator);
            var lang_iter = localizations.keyIterator();
            while (lang_iter.next()) |lang| {
                try std.fmt.format(array_list.writer(),
                    \\        .@"{s}" => switch(string) {{
                    \\{s}
                    \\        }},
                    \\
                , .{
                    lang.*,
                    blk2: {
                        var array_list2 = std.ArrayList(u8).init(allocator);
                        var string_iter = localizations.get(default_language).?.keyIterator();
                        while (string_iter.next()) |key| {
                            try std.fmt.format(array_list2.writer(),
                                \\            .@"{s}" => 
                                \\                \\{s}
                                \\            ,
                            , .{ key.*, localizations.get(lang.*).?.get(key.*) orelse localizations.get(default_language).?.get(key.*).? });
                        }
                        break :blk2 try array_list2.toOwnedSlice();
                    },
                });
            }
            break :blk try array_list.toOwnedSlice();
        },
    });
}
