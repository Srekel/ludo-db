const std = @import("std");
const t = @import("table.zig");

fn loadFile(path: []const u8, buffer: []u8) ![]const u8 {
    const data = try std.fs.cwd().readFile(path, buffer);
    return data;
}

pub fn loadProject(tables: *std.ArrayList(t.Table), allocator: std.mem.Allocator) !void {
    _ = tables; // autofix
    var buffer: [1024 * 4]u8 = undefined;
    const project_json = try loadFile("ludodb.project.json", &buffer);

    const jsonval = try std.json.parseFromSlice(std.json.Value, allocator, project_json, .{});
    defer jsonval.deinit();
}

pub const writeStream = std.json.writeStream;

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

fn writeProject(tables: []const t.Table, allocator: std.mem.Allocator) !void {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    var write_stream = writeStream(out.writer(), .{ .whitespace = .indent_2 });
    defer write_stream.deinit();

    {
        try write_stream.beginObject();
        defer write_stream.endObject() catch unreachable;
        {
            try write_stream.objectField("tables");

            try write_stream.beginArray();
            defer write_stream.endArray() catch unreachable;
            for (tables) |table_ptr| {
                // try write_stream.objectField(table_ptr.name.slice());
                try write_stream.beginObject();
                defer write_stream.endObject() catch unreachable;
                try write_stream.objectField("name");
                try write_stream.write(table_ptr.name.slice());
            }
        }
    }
    try writeFile(out.items, "ludo_db.project");
}

fn writeTable(table: t.Table, allocator: std.mem.Allocator) !void {
    var out = std.ArrayList(u8).init(allocator);
    defer out.deinit();
    var write_stream = writeStream(out.writer(), .{ .whitespace = .indent_2 });
    defer write_stream.deinit();

    var tables = std.ArrayList(*const t.Table).init(allocator);
    tables.append(&table) catch unreachable;
    for (table.columns.slice()) |column| {
        if (column.datatype == .subtable) {
            tables.append(column.datatype.subtable.table) catch unreachable;
        }
    }

    {
        try write_stream.beginObject();
        defer write_stream.endObject() catch unreachable;
        {
            try write_stream.objectField("table_metadatas");

            try write_stream.beginArray();
            defer write_stream.endArray() catch unreachable;
            for (tables.items) |table_ptr| {
                try writeTableMetadata(table_ptr.*, &write_stream);
            }
        }

        {
            try write_stream.objectField("table_datas");

            try write_stream.beginArray();
            defer write_stream.endArray() catch unreachable;
            for (tables.items) |table_ptr| {
                try writeTableData(table_ptr.*, &write_stream);
            }
        }
    }
    try writeFile(out.items, table.name.slice());
}

fn writeTableMetadata(table: t.Table, write_stream: anytype) !void {
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
                try writeColumnMetadata(table, column, write_stream);
            }
        }
    }
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
        .reference => |value| {
            try write_stream.objectField("reference_table");
            try write_stream.write(value.table.name.slice());
            try write_stream.objectField("reference_column");
            try write_stream.write(value.column.name.slice());
            try write_stream.objectField("reference_default");
            try write_stream.write(value.default);
        },
        .subtable => {
            const subtable = column.datatype.subtable.table;
            try write_stream.objectField("subtable_name");
            try write_stream.write(subtable.name.slice());
        },
        else => {},
    }
}

fn writeTableData(table: t.Table, write_stream: anytype) !void {
    try write_stream.beginObject();
    defer write_stream.endObject() catch unreachable;

    try write_stream.objectField("name");
    try write_stream.write(table.name.slice());

    try write_stream.objectField("rows");
    try write_stream.beginArray();
    defer write_stream.endArray() catch unreachable;
    for (0..table.row_count) |row_i| {
        try writeRow(table, row_i, write_stream);
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

    try writeProject(tables, gpa);
}
