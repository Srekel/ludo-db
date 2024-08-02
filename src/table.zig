const std = @import("std");
const zgui = @import("zgui");

const ROW_COUNT = 1 * 1024;

pub fn drawElement(table: Table, column: Column, i_row: usize) ?*Table {
    _ = table; // autofix

    const cell_data = column.data.slice()[i_row];
    switch (column.datatype) {
        .integer => |value| drawInteger(std.mem.asBytes(&value), cell_data),
        .text => drawText(cell_data),
        .reference => |value| drawReference(std.mem.asBytes(&value), cell_data),
        .subtable => |value| return drawSubtable(std.mem.asBytes(&value), cell_data, column),
        // else => {},
    }

    return null;
}

pub fn drawInteger(config_bytes: []const u8, celldata: []u8) void {
    const config: *const ColumnInteger = @alignCast(std.mem.bytesAsValue(ColumnInteger, config_bytes));
    const int: *i64 = @alignCast(std.mem.bytesAsValue(i64, celldata));
    var buf: [1024 * 4]u8 = undefined;
    const int_str = std.fmt.bufPrintZ(&buf, "{d}", .{int.*}) catch unreachable;
    _ = int_str; // autofix

    zgui.setNextItemWidth(-1);
    const drag_speed: f32 = 0.2;
    _ = drag_speed; // autofix

    _ = zgui.dragScalar("", i64, .{
        .v = int,
        .min = config.min,
        .max = config.max,
    });

    // _ = zgui.inputText(
    //     "",
    //     .{ .buf = @ptrCast(&buf) },
    // );

    // const int_value = std.fmt.parseInt(i64, &buf, 10) catch blk: {
    //     break :blk int.*;
    // };
    // int.* = int_value;
}

pub fn drawText(celldata: []u8) void {
    const text: [:0]u8 = @ptrCast(celldata);
    zgui.setNextItemWidth(-1);
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
    zgui.setNextItemWidth(-1);
    _ = zgui.combo("##refcombo", .{
        .current_item = @ptrCast(i_row),
        .items_separated_by_zeros = @ptrCast(buf.items),
        .popup_max_height_in_items = 10,
    });
    // }
}

pub fn drawSubtable(config_bytes: []const u8, celldata: []u8, column: Column) ?*Table {
    _ = config_bytes;
    const is_active: *bool = std.mem.bytesAsValue(bool, celldata);
    if (zgui.button("TABLE", .{})) {
        is_active.* = !is_active.*;
    }
    if (is_active.*) {
        return column.datatype.subtable.table;
    }
    return null;
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

pub const ColumnInteger = struct {
    default: i64 = 0,
    min: i64 = std.math.minInt(i64),
    max: i64 = std.math.maxInt(i64),
    is_primary_key: bool = false,
};

pub const ColumnType = union(enum) {
    integer: ColumnInteger,
    text: struct {
        default: [:0]const u8 = "",
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
    visible: bool = true,
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

    pub fn getRow(self: *Column, row: usize) []u8 {
        return self.data.buffer[row];
    }
    pub fn getRowAs(self: *Column, row: usize, T: type) *T {
        return @alignCast(@ptrCast(self.data.buffer[row]));
    }
    pub fn addRow(self: *Column, allocator: std.mem.Allocator) void {
        switch (self.datatype) {
            .integer => |value| {
                const i_row = allocator.create(i64) catch unreachable;
                i_row.* = value.default;
                if (value.is_primary_key) {
                    i_row.* = self.data.len + 1;
                }
                const i_row_bytes = std.mem.asBytes(i_row);
                self.data.appendAssumeCapacity(i_row_bytes);
            },
            .text => |value| {
                const string = allocator.allocSentinel(u8, value.text_len, 0) catch unreachable;
                @memcpy(string[0..value.default.len], value.default);
                // string[value.default.len] = @intCast(50 + self.data.len);
                string[value.default.len] = 0;
                self.data.appendAssumeCapacity(string);
            },
            .reference => |value| {
                const i_row = allocator.create(u32) catch unreachable;
                i_row.* = value.default;
                const i_row_bytes = std.mem.asBytes(i_row);
                self.data.appendAssumeCapacity(i_row_bytes);
            },
            .subtable => |value| {
                _ = value;
                const is_active = allocator.create(bool) catch unreachable;
                is_active.* = false;
                const is_active_bytes = std.mem.asBytes(is_active);
                self.data.appendAssumeCapacity(is_active_bytes);
            },
            // else => {},
        }
    }
};

pub const Table = struct {
    name: std.BoundedArray(u8, 128) = .{},
    allocator: std.mem.Allocator,
    columns: std.BoundedArray(Column, 32) = .{},
    row_count: u32 = 0,
    subtables: std.ArrayList(*Table),
    is_subtable: bool = false,
    uid: u32 = 0,

    pub fn init(self: *Table, name: []const u8, allocator: std.mem.Allocator) void {
        self.* = .{
            .name = std.BoundedArray(u8, 128).fromSlice(name) catch unreachable,
            .allocator = allocator,
            .subtables = std.ArrayList(*Table).initCapacity(allocator, 4) catch unreachable,
        };

        const column: Column = .{
            .name = std.BoundedArray(u8, 128).fromSlice("Row") catch unreachable,
            .owner_table = self,
            .datatype = .{ .integer = .{ .min = 0 } },
            .visible = false,
        };
        self.columns.appendAssumeCapacity(column);
    }

    pub fn addRow(self: *Table) void {
        self.row_count += 1;
        for (self.columns.slice()) |*column| {
            column.addRow(self.allocator);
        }
    }

    pub fn visibleColumnCount(self: Table) i32 {
        var count: i32 = 0;
        for (self.columns.slice()) |column| {
            if (column.visible) {
                count += 1;
            }
        }
        return count;
    }

    pub fn getColumn(self: *Table, name: []const u8) ?*Column {
        for (self.columns.slice()) |*column| {
            if (std.mem.eql(u8, name, column.name.slice())) {
                return column;
            }
        }

        return null;
    }
};
