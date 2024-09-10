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

fn writeTable(table: *const t.Table, allocator: std.mem.Allocator) !void {
    var buf: [256]u8 = undefined;
    var buf2: [256]u8 = undefined;
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();

    var writer = out.writer();

    _ = try writer.write("//\n");
    _ = try writer.write("// AUTO GENERATATED BY Ludo DB\n");
    _ = try writer.write("//\n");
    _ = try writer.write("\n");
    _ = try writer.write("pub const LudoString = []u8;\n");
    _ = try writer.write("\n");

    var subtable_fk_count: [128]usize = .{0} ** 128;

    for (table.columns.slice(), 0..) |column, i_col| {
        if (column.datatype == .subtable) {
            const subtable = column.datatype.subtable.table;
            subtable_fk_count[i_col] = try writeSubTable(subtable, &writer);
        }
    }

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

    col: for (table.columns.slice(), 0..) |column, i_col| {
        const type_str = switch (column.datatype) {
            .integer => |value| if (value.is_primary_key) continue :col else "i64",
            .reference => "u64",
            .text => "LudoString",
            .subtable => |value| try std.fmt.bufPrintZ(
                &buf2,
                "[{d}]{s}",
                .{ subtable_fk_count[i_col], value.table.name.slice() },
            ),
        };
        const col_str = try std.fmt.bufPrintZ(
            &buf,
            "    {s}: [row_count]{s} = undefined,\n",
            .{ column.name.slice(), type_str },
        );
        _ = try writer.write(col_str);
    }

    _ = try writer.write("};\n\n");

    try writeTableData(table, writer);

    const filepath = std.fmt.bufPrintZ(&buf, "{s}.table", .{table.name.slice()}) catch unreachable;
    try writeFile(out.items, filepath);
}

fn writeSubTable(table: *const t.Table, writer: *std.ArrayList(u8).Writer) !usize {
    var buf: [256]u8 = undefined;

    for (table.columns.slice()) |column| {
        if (column.datatype == .subtable) {
            const subtable = column.datatype.subtable.table;
            _ = try writeSubTable(subtable, writer);
        }
    }

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

    var max_fk_count: usize = 0;

    const column_fk = table.getColumnConst("FK").?;
    for (1..table.row_count) |i_row1| {
        const fk1 = column_fk.datatype.reference.getContent(i_row1).?;
        var count: usize = 1;
        for (i_row1..table.row_count) |i_row2| {
            const fk2 = column_fk.datatype.reference.getContent(i_row2);
            if (fk1 == fk2) {
                count += 1;
            }
        }
        max_fk_count = @max(max_fk_count, count);
    }

    const fk_count = try std.fmt.bufPrintZ(
        &buf,
        "    pub const max_fk_count = {d};\n",
        .{max_fk_count},
    );

    _ = try writer.write(fk_count);
    _ = try writer.write("\n");

    col: for (table.columns.slice()[2..]) |column| {
        const type_str = switch (column.datatype) {
            .integer => |value| if (value.is_primary_key) continue :col else "i64",
            .reference => "u64",
            .text => "LudoString",
            else => continue :col,
        };
        const col_str = try std.fmt.bufPrintZ(
            &buf,
            "    {s}: {s} = undefined,\n",
            .{ column.name.slice(), type_str },
        );
        _ = try writer.write(col_str);
    }

    _ = try writer.write("};\n\n");

    return max_fk_count;
}

pub fn writeTableData(table: *const t.Table, writer: std.ArrayList(u8).Writer) !void {
    var buf: [256]u8 = undefined;
    var buf2: [256]u8 = undefined;

    // for (table.columns.slice()) |column| {
    //     if (column.datatype == .subtable) {
    //         const subtable = column.datatype.subtable.table;
    //         _ = try writeSubTable(subtable, writer);
    //     }
    // }

    const fn_begin = try std.fmt.bufPrintZ(
        &buf,
        "pub fn create_{s}() {s} {{\n",
        .{ table.name.slice(), table.name.slice() },
    );
    _ = try writer.write(fn_begin);

    const table_name = try std.fmt.bufPrintZ(
        &buf,
        "    const table : {s} = .{{\n",
        .{table.name.slice()},
    );

    _ = try writer.write(table_name);

    for (table.columns.slice()[2..]) |column| {
        const col_str = try std.fmt.bufPrintZ(
            &buf,
            "        .{s} = .{{\n",
            .{column.name.slice()},
        );
        _ = try writer.write(col_str);

        switch (column.datatype) {
            .integer => {
                for (1..table.row_count) |i_row| {
                    const written = column.toBuf(i_row, &buf);

                    const row_str = try std.fmt.bufPrintZ(
                        &buf2,
                        "            {s},\n",
                        .{buf[0..written]},
                    );
                    _ = try writer.write(row_str);
                }
            },
            .text => {
                for (1..table.row_count) |i_row| {
                    const written = column.toBuf(i_row, &buf);

                    const row_str = try std.fmt.bufPrintZ(
                        &buf2,
                        "            \"{s}\",\n",
                        .{buf[0..written]},
                    );
                    _ = try writer.write(row_str);
                }
            },
            .reference => |value| {
                const ref_str = try std.fmt.bufPrintZ(
                    &buf2,
                    "            // Reference to {s}::{s}\n",
                    .{ value.table.name.slice(), value.column.name.slice() },
                );
                _ = try writer.write(ref_str);

                for (1..table.row_count) |i_row| {
                    const written = column.toBuf(i_row, &buf);

                    const row_str = try std.fmt.bufPrintZ(
                        &buf2,
                        "            {d}, // {s}\n",
                        .{ value.getContent(i_row).?, buf[0..written] },
                    );
                    _ = try writer.write(row_str);
                }
            },
            .subtable => |value| {
                const subtable = value.table;
                const column_fk = subtable.getColumnConst("FK").?;

                for (1..table.row_count) |i_row1| {
                    _ = try writer.write("         .{");

                    for (1..subtable.row_count) |i_row2| {
                        const fk2 = column_fk.datatype.reference.getContent(i_row2).?;
                        if (fk2 == i_row1) {
                            // TODO functionize
                            for (subtable.columns.slice()[2..]) |column2| {
                                switch (column2.datatype) {
                                    .integer => {
                                        const written = column2.toBuf(i_row2, &buf);

                                        const row_str = try std.fmt.bufPrintZ(
                                            &buf2,
                                            "{s},",
                                            .{buf[0..written]},
                                        );
                                        _ = try writer.write(row_str);
                                    },
                                    .text => {
                                        const written = column2.toBuf(i_row2, &buf);

                                        const row_str = try std.fmt.bufPrintZ(
                                            &buf2,
                                            "\"{s}\",",
                                            .{buf[0..written]},
                                        );
                                        _ = try writer.write(row_str);
                                    },
                                    .reference => |value2| {
                                        const written = column2.toBuf(i_row2, &buf);
                                        _ = written; // autofix

                                        const row_str = try std.fmt.bufPrintZ(
                                            &buf2,
                                            "{d},",
                                            .{value2.getContent(i_row2).?},
                                        );
                                        _ = try writer.write(row_str);
                                    },
                                    .subtable => |value2| {
                                        _ = value2; // autofix
                                        // const subtable2 = value.table;
                                        // const column_fk = subtable.getColumnConst("FK").?;

                                        // for (1..table.row_count) |i_row1| {
                                        //     _ = try writer.write("         .{");

                                        //     for (1..subtable.row_count) |i_row2| {
                                        //         const fk2 = column_fk.datatype.reference.getContent(i_row2).?;
                                        //         if (fk2 == i_row1) {
                                        //             _ = try writer.write("LOL");
                                        //         }
                                        //     }
                                        //     _ = try writer.write("         },\n");
                                        // }
                                    },
                                }

                                _ = try writer.write("LOL");
                            }
                        }
                        _ = try writer.write("         },\n");
                    }
                }
            },
        }
    }
    _ = try writer.write("        },\n\n");

    _ = try writer.write("    };\n\n");
    _ = try writer.write("    return table;\n");
    _ = try writer.write("}\n\n");
}

pub fn saveProject(tables: []const *t.Table) !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    try writeProject(tables, gpa);
    for (tables) |table| {
        if (table.is_subtable) {
            continue;
        }
        try writeTable(table, gpa);
    }

    try writeProject(tables, gpa);
}
