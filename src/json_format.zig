const std = @import("std");
const t = @import("table.zig");

// pub const ColumnReference = struct {
//     table: *Table,
//     column: *Column,
//     default: u32 = 0,
// };

// pub const SubTable = struct {
//     table: *Table,
// };

// pub const ColumnType = union(enum) {
//     text: struct {
//         default: [:0]const u8 = "empty",
//         text_len: u32 = 32,
//     },
//     reference: ColumnReference,
//     subtable: SubTable,
// };

// pub const Column = struct {
//     name: std.BoundedArray(u8, 128) = .{},
//     data: std.ArrayList(ColumnType) = .{},
// };

// pub const Table = struct {
//     name: std.BoundedArray(u8, 128) = .{},
//     allocator: std.mem.Allocator,
//     columns: std.BoundedArray(Column, 32) = .{},
//     row_count: u32 = 0,
//     subtables: std.ArrayList(Table),
// };

// pub const Sheets = std.ArrayList(Table);

const json = std.json;
pub const StringifyOptions = json.StringifyOptions;
pub const stringify = json.stringify;
pub const stringifyMaxDepth = json.stringifyMaxDepth;
pub const stringifyArbitraryDepth = json.stringifyArbitraryDepth;
pub const stringifyAlloc = json.stringifyAlloc;
pub const writeStream = json.writeStream;
pub const writeStreamMaxDepth = json.writeStreamMaxDepth;
pub const writeStreamArbitraryDepth = json.writeStreamArbitraryDepth;
pub const WriteStream = json.WriteStream;
pub const encodeJsonString = json.encodeJsonString;
pub const encodeJsonStringChars = json.encodeJsonStringChars;

fn writeFile(data: anytype, name: []const u8) !void {
    var buf: [256]u8 = undefined;

    const filepath = std.fmt.bufPrintZ(&buf, "{s}.json", .{name}) catch unreachable;

    const file = try std.fs.cwd().createFile(
        filepath,
        .{ .read = true },
    );
    defer file.close();

    const bytes_written = try file.writeAll(data);
    _ = bytes_written; // autofix
}

fn writeTable(table: t.Table, allocator: std.mem.Allocator) !void {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    var write_stream = writeStream(out.writer(), .{ .whitespace = .indent_2 });
    defer write_stream.deinit();

    {
        try write_stream.beginObject();
        defer write_stream.endObject() catch unreachable;

        try write_stream.objectField("name");
        try write_stream.write(table.name.slice());

        try write_stream.objectField("row_count");
        try write_stream.write(table.row_count);

        {
            // Column metadata
            try write_stream.objectField("column_metadata");
            try write_stream.beginArray();
            defer write_stream.endArray() catch unreachable;
            for (table.columns.slice()) |column| {
                try writeColumnMetadata(table, column, &write_stream);
            }
        }

        {
            // Rows
            try write_stream.objectField("rows");
            try write_stream.beginArray();
            defer write_stream.endArray() catch unreachable;
            for (0..table.row_count) |row_i| {
                try writeRow(table, row_i, &write_stream);
            }
        }
    }

    try writeFile(out.items, table.name.slice());
}

fn writeColumnMetadata(table: t.Table, column: t.Column, write_stream: anytype) !void {
    _ = table; // autofix
    try write_stream.beginObject();
    defer write_stream.endObject() catch unreachable;

    try write_stream.objectField("name");
    try write_stream.write(column.name.slice());

    try write_stream.objectField("visible");
    try write_stream.write(column.visible);

    try write_stream.objectField("datatype");
    try write_stream.write(@tagName(column.datatype));

    switch (column.datatype) {
        .subtable => {
            const subtable = column.datatype.subtable.table;
            try write_stream.objectField("subtable_name");
            try write_stream.write(subtable.name.slice());
        },
        else => {},
    }
}

fn writeRow(table: t.Table, row: usize, write_stream: anytype) !void {
    try write_stream.beginObject();
    defer write_stream.endObject() catch unreachable;

    try write_stream.objectField("index");
    try write_stream.write(row);

    for (table.columns.slice()) |column| {
        try write_stream.objectField(column.name.slice());
        const celldata = column.data.slice()[row];
        switch (column.datatype) {
            .text => {
                const text = celldata[0..std.mem.indexOfScalar(u8, celldata, 0).?];
                try write_stream.write(text);
            },
            .reference => {
                const i_row: *u32 = @alignCast(std.mem.bytesAsValue(u32, celldata));
                try write_stream.write(i_row);
            },
            .subtable => {
                try write_stream.write("subtable");
                // const subtable = column.datatype.subtable.table;
                // try write_stream.write(i_row);
            },
            // else => {
            //     try write_stream.write("unknown");
            // },
        }
    }
}

pub fn exportProject(tables: []const t.Table) !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    for (tables) |table| {
        try writeTable(table, gpa);
    }
}
