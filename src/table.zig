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
        else => {},
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
    const y = zgui.getCursorPosY();
    const config: *const ColumnReference = @alignCast(std.mem.bytesAsValue(ColumnReference, config_bytes));
    const i_row: *u32 = @alignCast(std.mem.bytesAsValue(u32, celldata));
    // zgui.beginDisabled(.{ .disabled = true });
    // zgui.setNextItemAllowOverlap();
    // drawElement(config.table.*, config.column.*, i_row.*);
    // zgui.endDisabled();
    // if (zgui.isItemHovered(.{ .allow_when_disabled = true })) {
    // zgui.sameLine(.{});
    const size = zgui.getItemRectSize();
    _ = size; // autofix
    // zgui.setCursorPosX(zgui.getCursorPosX() - size[0]);
    // zgui.setCursorPosY(zgui.getCursorPosY() - size[1]);
    zgui.setCursorPosY(y);
    // drawElement(config.table.*, config.column.*, i_row.*);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();
    for (config.column.data.slice()) |text| {
        _ = writer.write(text[0..std.mem.indexOf(u8, text, "\x00").?]) catch unreachable;
        _ = writer.writeByte(0) catch unreachable;
    }
    _ = writer.writeByte(0) catch unreachable;
    // _ = writer.write("LOL") catch unreachable;
    // _ = writer.writeByte(0) catch unreachable;

    // var item: i32 = @intCast(i_row.*);
    _ = zgui.combo("##refcombo", .{
        .current_item = @ptrCast(i_row),
        .items_separated_by_zeros = @ptrCast(buf.items),
        .popup_max_height_in_items = 10,
    });
    // }
}

pub const ColumnReference = struct {
    table: *Table,
    column: *Column,
    default: u32 = 0,
};

pub const SubTable = struct {
    table: *Table,
    // column: *Column,
    // default: u32 = 0,
};

pub const ColumnType = union(enum) {
    text: struct {
        default: [:0]const u8 = "empty",
        text_len: u32 = 32,
    },
    reference: ColumnReference,
    subtable: SubTable,
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
    owner_table: *Table,
    datatype: ColumnType,
    data: std.BoundedArray([]u8, ROW_COUNT) = .{},

    // pub fn setType(self: *Column, datatype: ColumnType) void {
    //     self.datatype = datatype;
    //     switch (datatype) {
    //         .subtable => {
    //             var subtable = self.parent_table.subtables.addOneAssumeCapacity();
    //             _ = subtable; // autofix
    //         },
    //         else => void,
    //     }
    // }
};

pub const Table = struct {
    name: std.BoundedArray(u8, 128) = .{},
    allocator: std.mem.Allocator,
    columns: std.BoundedArray(Column, 32) = .{},
    row_count: u32 = 0,
    subtables: std.ArrayList(Table),

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
                else => {},
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
