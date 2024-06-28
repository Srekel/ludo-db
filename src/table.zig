const std = @import("std");

const ROW_COUNT = 16 * 1024;

const ColumnType = enum {
    text,
    number_float,
    number_integer,
    column_ref,
};

const Column = struct {
    name: std.BoundedArray(u8, 128) = .{},
    datatype: ColumnType,
    rows: std.BoundedArray(u32, ROW_COUNT) = .{},
    data: std.BoundedArray([]u8, ROW_COUNT) = .{},
};

const Table = struct {
    name: std.BoundedArray(u8, 128) = .{},
    columns: std.BoundedArray(Column, 32),
};

fn main() void {
    var table: Table = .{
        .name = std.BoundedArray(u8, 128).fromSlice("classification"),
    };
    {
        const column: Column = .{
            .name = std.BoundedArray(u8, 128).fromSlice("classification"),
            .datatype = .text,
        };
        table.columns.appendAssumeCapacity(column);
    }
    {
        const column: Column = .{
            .name = std.BoundedArray(u8, 128).fromSlice("parents"),
            .datatype = .table,
        };
        table.columns.appendAssumeCapacity(column);
    }
}
