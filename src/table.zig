const std = @import("std");
const zgui = @import("zgui");

const ROW_COUNT = 1 * 1024;

pub fn drawElement(table: Table, column: Column, i_row: usize) void {
    _ = table; // autofix

    const cell_data = column.data.slice()[i_row];
    switch (column.datatype) {
        .text => {
            drawText(cell_data);
        },
        .reference => |value| drawReference(std.mem.asBytes(&value), cell_data),
    }
}

pub fn drawText(celldata: []u8) void {
    const text: [:0]u8 = @ptrCast(celldata);
    _ = zgui.inputText(
        "",
        .{ .buf = text },
    );
}

pub fn drawReference(config_bytes: []const u8, celldata: []u8) void {
    const config: *const ColumnReference = @alignCast(std.mem.bytesAsValue(ColumnReference, config_bytes));
    const i_row: *u32 = @alignCast(std.mem.bytesAsValue(u32, celldata));
    zgui.beginDisabled(.{ .disabled = true });
    drawElement(config.table.*, config.column.*, i_row.*);
    zgui.endDisabled();
}

pub const ColumnReference = struct {
    table: *Table,
    column: *Column,
    default: u32 = 0,
};

pub const ColumnType = union(enum) {
    text: struct {
        default: [:0]const u8 = "empty",
        text_len: u32 = 32,
    },
    reference: ColumnReference,
    // number_float: .{
    //     .cellsize = @sizeOf(f32),
    // },
    // number_integer: .{
    //     .cellsize = @sizeOf(i32),
    // },
    // column_ref: .{
    //     .cellsize = @sizeOf(u32),
    // },
};

pub const Column = struct {
    name: std.BoundedArray(u8, 128) = .{},
    datatype: ColumnType,
    data: std.BoundedArray([]u8, ROW_COUNT) = .{},
};

pub const Table = struct {
    name: std.BoundedArray(u8, 128) = .{},
    allocator: std.mem.Allocator,
    columns: std.BoundedArray(Column, 32) = .{},
    row_count: u32 = 0,
    pub fn addRow(self: *Table) void {
        self.row_count += 1;
        for (self.columns.slice()) |*column| {
            switch (column.datatype) {
                .text => |value| {
                    const string = self.allocator.allocSentinel(u8, value.text_len, 0) catch unreachable;
                    @memcpy(string[0..value.default.len], value.default);
                    string[value.default.len] = @intCast(50 + self.row_count);
                    string[value.default.len + 1] = 0;
                    column.data.appendAssumeCapacity(string);
                },
                .reference => |value| {
                    const i_row = self.allocator.create(u32) catch unreachable;
                    i_row.* = value.default;
                    const i_row_bytes = std.mem.asBytes(i_row);
                    column.data.appendAssumeCapacity(i_row_bytes);
                },
            }
        }
    }
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
