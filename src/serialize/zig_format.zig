const std = @import("std");
const t = @import("../table.zig");

const VERSION_LATEST = 1;

// ███████╗ █████╗ ██╗   ██╗███████╗
// ██╔════╝██╔══██╗██║   ██║██╔════╝
// ███████╗███████║██║   ██║█████╗
// ╚════██║██╔══██║╚██╗ ██╔╝██╔══╝
// ███████║██║  ██║ ╚████╔╝ ███████╗
// ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝

pub const writeStream = std.json.writeStream;

fn writeFile(data: anytype, name: []const u8) !void {
    var buf: [256]u8 = undefined;

    const filepath = std.fmt.bufPrintZ(&buf, "{s}.zig", .{name}) catch unreachable;

    std.log.debug("LOL1 {s}", .{name});
    std.log.debug("LOL2 {s}", .{filepath});

    const file = try std.fs.cwd().createFile(
        filepath,
        .{ .read = true },
    );
    defer file.close();

    const bytes_written = try file.writeAll(data);
    _ = bytes_written; // autofix
}

fn writeProject(tables: []const *t.Table, allocator: std.mem.Allocator) !void {
    var buf: [256]u8 = undefined;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    var writer = out.writer();

    _ = try writer.write("//\n");
    _ = try writer.write("// AUTO GENERATATED BY Ludo DB\n");
    _ = try writer.write("//\n");

    for (tables) |table| {
        const table_import = try std.fmt.bufPrintZ(&buf, "pub const {s} = @import(\"{s}.table.zig\");\n", .{
            table.name.slice(),
            table.name.slice(),
        });
        _ = std.mem.replace(u8, table_import, ":", "_", table_import);
        // std.ascii.upperString(table_import, table_import);
        _ = try writer.write(table_import);
    }

    try writeFile(out.items, "ludo_db.project");
}

fn writeTable(table: t.Table, allocator: std.mem.Allocator) !void {
    var buf: [256]u8 = undefined;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    var writer = out.writer();

    _ = try writer.write("//\n");
    _ = try writer.write("// AUTO GENERATATED BY Ludo DB\n");
    _ = try writer.write("//\n");
    _ = try writer.write("\n");
    _ = try writer.write("pub const LudoString = []u8;\n");
    _ = try writer.write("\n");

    const table_struct_begin = try std.fmt.bufPrintZ(
        &buf,
        "pub const {s} = struct {{\n",
        .{table.name.slice()},
    );
    _ = try writer.write(table_struct_begin);

    const table_name = try std.fmt.bufPrintZ(
        &buf,
        "    pub const name = \"{s}\";\n",
        .{table.name.slice()},
    );

    _ = try writer.write(table_name);

    const row_count = try std.fmt.bufPrintZ(
        &buf,
        "    pub const row_count = {d};\n",
        .{table.row_count},
    );

    _ = try writer.write(row_count);
    _ = try writer.write("\n");

    for (table.columns.slice()) |column| {
        // col : coltype = undefined,
        const type_str = switch (column.datatype) {
            .integer => "i64",
            .reference => "u64",
            .text => "LudoString",
            else => "unknown",
        };
        const col_str = try std.fmt.bufPrintZ(
            &buf,
            "    {s}: [row_count]{s} = undefined,\n",
            .{ column.name.slice(), type_str },
        );
        _ = try writer.write(col_str);
    }

    _ = try writer.write("};\n");

    const filepath = std.fmt.bufPrintZ(&buf, "{s}.table", .{table.name.slice()}) catch unreachable;
    try writeFile(out.items, filepath);
}

pub fn saveProject(tables: []const *t.Table) !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    try writeProject(tables, gpa);
    for (tables) |table| {
        try writeTable(table.*, gpa);
    }

    try writeProject(tables, gpa);
}
