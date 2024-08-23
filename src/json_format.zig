const std = @import("std");
const t = @import("table.zig");

const VERSION_LATEST = 2;

// ██╗      ██████╗  █████╗ ██████╗
// ██║     ██╔═══██╗██╔══██╗██╔══██╗
// ██║     ██║   ██║███████║██║  ██║
// ██║     ██║   ██║██╔══██║██║  ██║
// ███████╗╚██████╔╝██║  ██║██████╔╝
// ╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝

fn loadFile(path: []const u8, buf: []u8) ![]const u8 {
    const data = try std.fs.cwd().readFile(path, buf);
    return data;
}

pub fn loadProject(tables: *std.ArrayList(*t.Table), allocator: std.mem.Allocator) !void {
    var buf: [1024 * 4]u8 = undefined;
    const project_json = try loadFile("ludo_db.project.json", &buf);

    const j_root = try std.json.parseFromSlice(std.json.Value, allocator, project_json, .{});
    defer j_root.deinit();

    const j_version_opt = j_root.value.object.get("version");
    const version = if (j_version_opt) |j_version| j_version.integer else 1;

    const j_tables = j_root.value.object.get("tables").?;

    // Phase 1, create barebones tables
    for (j_tables.array.items) |j_table| {
        const j_name = j_table.object.get("name");
        const name = j_name.?.string;
        const table = try loadTable(name, tables, allocator);
        _ = table; // autofix
    }

    // Phase 2, link tables
    for (j_tables.array.items) |j_table| {
        const j_name = j_table.object.get("name");
        const name = j_name.?.string;
        try finalizeTable(name, tables, version, allocator);
    }
}

var fallback_uid: u32 = 0;

fn loadTable(name: []const u8, tables: *std.ArrayList(*t.Table), allocator: std.mem.Allocator) !*t.Table {
    var buf: [1024 * 4]u8 = undefined;
    const filepath = std.fmt.bufPrintZ(&buf, "{s}.table.json", .{name}) catch unreachable;
    const table_json = try loadFile(filepath, &buf);

    const j_root = try std.json.parseFromSlice(std.json.Value, allocator, table_json, .{});
    defer j_root.deinit();

    var main_table: ?*t.Table = null;

    const j_metadatas = j_root.value.object.get("table_metadatas").?;
    for (j_metadatas.array.items) |j_table_metadata| {
        const j_name = j_table_metadata.object.get("name");
        var table = allocator.create(t.Table) catch unreachable;
        fallback_uid += 1;
        const uid: u32 = if (j_table_metadata.object.get("uid")) |table_uid| @intCast(table_uid.integer) else fallback_uid;
        table.* = t.Table{
            .name = std.BoundedArray(u8, 128).fromSlice(j_name.?.string) catch unreachable,
            .allocator = allocator,
            .subtables = std.ArrayList(*t.Table).initCapacity(allocator, 4) catch unreachable,
            .is_subtable = j_table_metadata.object.get("is_subtable").?.bool,
            .uid = uid,
        };

        tables.appendAssumeCapacity(table);

        if (main_table == null) {
            main_table = table;
        }

        const j_column_metadata = j_table_metadata.object.get("column_metadata").?;
        for (j_column_metadata.array.items) |j_cmd| {
            const column: t.Column = .{
                .name = std.BoundedArray(u8, 128).fromSlice(j_cmd.object.get("name").?.string) catch unreachable,
                .owner_table = table,
                .visible = j_cmd.object.get("visible").?.bool,
                .datatype = undefined, // fill out in phase 2
            };
            table.columns.append(column) catch unreachable;
        }

        // Add empty first "0" row
        table.addRow();
    }

    return main_table.?;
}

fn getTable(name: []const u8, tables: *std.ArrayList(*t.Table)) *t.Table {
    for (tables.items) |table| {
        if (std.mem.eql(u8, name, table.name.slice())) {
            return table;
        }
    }
    unreachable;
}

fn finalizeTable(name: []const u8, tables: *std.ArrayList(*t.Table), version: i64, allocator: std.mem.Allocator) !void {
    var buf: [1024 * 4]u8 = undefined;
    const filepath = std.fmt.bufPrintZ(&buf, "{s}.table.json", .{name}) catch unreachable;
    const table_json = try loadFile(filepath, &buf);

    const j_root = try std.json.parseFromSlice(std.json.Value, allocator, table_json, .{});
    defer j_root.deinit();

    const j_metadatas = j_root.value.object.get("table_metadatas").?;
    for (j_metadatas.array.items) |j_table_metadata| {
        const j_name = j_table_metadata.object.get("name");
        const table_name = j_name.?.string;
        const table = getTable(table_name, tables);

        const j_column_metadata = j_table_metadata.object.get("column_metadata").?;
        for (j_column_metadata.array.items) |j_cmd| {
            const column = table.getColumn(j_cmd.object.get("name").?.string).?;
            const datatype = j_cmd.object.get("datatype").?.string;
            if (std.mem.eql(u8, datatype, "integer")) {
                const is_primary_key = j_cmd.object.get("is_primary_key").?.bool;
                const min = j_cmd.object.get("min").?.integer;
                const max = j_cmd.object.get("max").?.integer;
                const default = j_cmd.object.get("default").?.integer;

                column.datatype = .{ .integer = .{
                    .self_column = column,
                    .is_primary_key = is_primary_key,
                    .min = min,
                    .max = max,
                    .default = default,
                } };
            }
            if (std.mem.eql(u8, datatype, "text")) {
                // TODO: Read metadata settings
                column.datatype = .{ .text = .{
                    .self_column = column,
                } };
            }
            if (std.mem.eql(u8, datatype, "reference")) {
                // TODO: Read metadata settings
                const ref_table = getTable(j_cmd.object.get("reference_table").?.string, tables);
                column.datatype = .{ .reference = .{
                    .self_column = column,
                    .table = ref_table,
                    .column = ref_table.getColumn(j_cmd.object.get("reference_column").?.string).?,
                } };
            }
            if (std.mem.eql(u8, datatype, "subtable")) {
                // TODO: Read metadata settings
                const subtable = getTable(j_cmd.object.get("subtable_name").?.string, tables);
                column.datatype = .{ .subtable = .{
                    .self_column = column,
                    .table = subtable,
                } };
            }
        }

        const row_count = j_table_metadata.object.get("row_count").?.integer;
        for (0..@intCast(row_count)) |i_row| {
            _ = i_row; // autofix
            table.addRow();
        }
    }

    // Add rows
    const j_table_datas = j_root.value.object.get("table_datas").?;
    for (j_table_datas.array.items) |j_table_metadata| {
        const j_name = j_table_metadata.object.get("name");
        const table_name = j_name.?.string;
        const table = getTable(table_name, tables);

        const j_rows = j_table_metadata.object.get("rows").?;
        for (j_rows.array.items, 1..) |j_row, i_row| {
            for (table.columns.slice()) |*column| {
                const j_celldata = j_row.object.get(column.name.slice());
                const celldata = &column.data.slice()[i_row];
                switch (column.datatype) {
                    .integer => {
                        const int = j_celldata.?.integer;
                        const celldata_row: *u32 = @alignCast(std.mem.bytesAsValue(u32, celldata.*));
                        celldata_row.* = @intCast(int);
                        if (column.datatype.integer.is_primary_key and version == 1) {
                            celldata_row.* += 1;
                        }
                    },
                    .text => {
                        const text_src = j_celldata.?.string;
                        const text_len = 32; // TODO
                        var text_dst = allocator.alloc(u8, text_len) catch unreachable;
                        @memcpy(text_dst[0..text_src.len], text_src);
                        text_dst[text_src.len] = 0;
                        celldata.* = text_dst;
                    },
                    .reference => {
                        const row = j_celldata.?.integer;
                        const celldata_row: *?u32 = @alignCast(std.mem.bytesAsValue(?u32, celldata.*));
                        if (row == -1) {
                            celldata_row.* = null;
                        } else {
                            celldata_row.* = @intCast(row);
                            if (version == 1) {
                                celldata_row.* = @intCast(row + 1);
                            }
                        }
                    },
                    .subtable => {},
                }
            }
        }
    }
}

// ███████╗ █████╗ ██╗   ██╗███████╗
// ██╔════╝██╔══██╗██║   ██║██╔════╝
// ███████╗███████║██║   ██║█████╗
// ╚════██║██╔══██║╚██╗ ██╔╝██╔══╝
// ███████║██║  ██║ ╚████╔╝ ███████╗
// ╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝

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

fn writeProject(tables: []const *t.Table, allocator: std.mem.Allocator) !void {
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
                if (table_ptr.is_subtable) {
                    continue;
                }
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
            try write_stream.objectField("version");
            try write_stream.write(VERSION_LATEST);

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

    var buf: [1024 * 4]u8 = undefined;
    const filepath = std.fmt.bufPrintZ(&buf, "{s}.table", .{table.name.slice()}) catch unreachable;
    try writeFile(out.items, filepath);
}

fn writeTableMetadata(table: t.Table, write_stream: anytype) !void {
    {
        try write_stream.beginObject();
        defer write_stream.endObject() catch unreachable;

        try write_stream.objectField("name");
        try write_stream.write(table.name.slice());

        try write_stream.objectField("uid");
        try write_stream.write(table.uid);

        try write_stream.objectField("row_count");
        try write_stream.write(table.row_count);

        try write_stream.objectField("is_subtable");
        try write_stream.write(table.is_subtable);

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
        .integer => |value| {
            try write_stream.objectField("is_primary_key");
            try write_stream.write(value.is_primary_key);
            try write_stream.objectField("min");
            try write_stream.write(value.min);
            try write_stream.objectField("max");
            try write_stream.write(value.max);
            try write_stream.objectField("default");
            try write_stream.write(value.default);
        },
        .text => |value| {
            _ = value; // autofix
        },
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
    for (1..table.row_count) |row_i| {
        try writeRow(table, row_i, write_stream);
    }
}

fn writeRow(table: t.Table, row: usize, write_stream: anytype) !void {
    try write_stream.beginObject();
    defer write_stream.endObject() catch unreachable;

    try write_stream.objectField("__index");
    try write_stream.write(row);

    for (table.columns.slice()) |column| {
        try write_stream.objectField(column.name.slice());
        const celldata = column.data.slice()[row];
        switch (column.datatype) {
            .integer => {
                const int: *i64 = @alignCast(std.mem.bytesAsValue(i64, celldata));
                try write_stream.write(int);
            },
            .text => {
                const text = celldata[0..std.mem.indexOfScalar(u8, celldata, 0).?];
                try write_stream.write(text);
            },
            .reference => {
                const i_row_opt: *?u32 = @alignCast(std.mem.bytesAsValue(?u32, celldata));
                if (i_row_opt.*) |i_row| {
                    try write_stream.write(i_row);
                } else {
                    try write_stream.write(-1);
                }
            },
            .subtable => {
                try write_stream.write("subtable");
            },
        }
    }
}

pub fn exportProject(tables: []const *t.Table) !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    for (tables) |table| {
        if (table.is_subtable) {
            continue;
        }
        try writeTable(table.*, gpa);
    }

    try writeProject(tables, gpa);
}
