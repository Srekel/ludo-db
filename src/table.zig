const std = @import("std");
const zgui = @import("zgui");
const plugin_common = @import("column_types/common.zig");
const column_text = @import("column_types/text.zig");
const column_integer = @import("column_types/integer.zig");
const ROW_COUNT = 1 * 1024;

// const primary_key = enum(u32) { _ };

pub const ColumnTypeRegistry = struct {
    registry: std.StringArrayHashMap(ColumnTypeAPI),

    pub fn init(self: *ColumnTypeRegistry, allocator: std.mem.Allocator) void {
        self.registry = std.StringArrayHashMap(ColumnTypeAPI).init(allocator);
        self.registry.ensureTotalCapacity(64) catch unreachable;
    }

    pub fn registerColumnType(self: *ColumnTypeRegistry, api: ColumnTypeAPI) void {
        self.registry.putAssumeCapacity(api.name[0..std.mem.len(api.name)], api);
    }
};

pub fn drawElement(table: Table, column: Column, i_row: usize) ?*Table {
    _ = table; // autofix

    const cell_data = column.data.slice()[i_row];
    switch (column.datatype) {
        .integer => |value| drawInteger(std.mem.asBytes(&value), cell_data),
        .text => drawText(cell_data),
        .reference => |value| drawReference(std.mem.asBytes(&value), cell_data),
        .subtable => |value| return drawSubtable(std.mem.asBytes(&value), cell_data, column, i_row),
        // else => {},
    }

    return null;
}

pub fn drawInteger(config_bytes: []const u8, celldata: []u8) void {
    const config: *const column_integer.ColumnInteger = @alignCast(std.mem.bytesAsValue(column_integer.ColumnInteger, config_bytes));
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
    const i_row_opt: *?u32 = @alignCast(std.mem.bytesAsValue(?u32, celldata));
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
    defer arena.deinit();
    const allocator = arena.allocator();
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    const writer = buf.writer();
    var buf2: [1024]u8 = undefined;

    _ = writer.write("<Null>") catch unreachable;
    _ = writer.writeByte(0) catch unreachable;
    for (1..config.table.row_count) |table_row| {
        const written = config.column.toBuf(table_row, &buf2);
        _ = writer.write(buf2[0..written]) catch unreachable;
        _ = writer.writeByte(0) catch unreachable;
    }
    _ = writer.writeByte(0) catch unreachable;

    zgui.setNextItemWidth(-1);
    const rowu: u32 = @intCast(if (i_row_opt.*) |i_row| i_row else 0);
    _ = rowu; // autofix
    var row: i32 = @intCast(if (i_row_opt.*) |i_row| i_row else 0);
    _ = zgui.combo("##refcombo", .{
        .current_item = &row,
        .items_separated_by_zeros = @ptrCast(buf.items),
        .popup_max_height_in_items = 10,
    });

    if (row == 0) {
        i_row_opt.* = null;
    } else {
        i_row_opt.* = @intCast(row);
    }
}

pub fn drawSubtable(config_bytes: []const u8, celldata: []u8, column: Column, i_row: usize) ?*Table {
    _ = config_bytes;
    const is_active: *bool = std.mem.bytesAsValue(bool, celldata);

    var buf: [1024]u8 = undefined;
    var len: usize = 0;
    const subtable = column.datatype.subtable.table;
    const column_fk = subtable.getColumn("FK").?;
    buf[len] = '[';
    len += 1;
    const subtable_columns = subtable.columns.slice();
    var has_one = false;
    for (1..subtable.row_count) |i_row_st| {
        const data_fk: *u32 = @alignCast(std.mem.bytesAsValue(u32, column_fk.data.slice()[i_row_st]));
        if (i_row != data_fk.*) {
            continue;
        }

        if (has_one) {
            buf[len] = ',';
            len += 1;
            buf[len] = ' ';
            len += 1;
        }

        if (subtable_columns.len > 3) {
            buf[len] = '{';
            len += 1;
            has_one = true;
        }

        for (subtable_columns[2..], 2..) |subcolumn, i_subcolumn| {
            len += subcolumn.toBuf(i_row_st, buf[len..buf.len]);
            if (i_subcolumn + 1 < subtable_columns.len) {
                buf[len] = ',';
                len += 1;
                buf[len] = ' ';
                len += 1;
            }
            has_one = true;
        }

        if (subtable_columns.len > 3) {
            buf[len] = '}';
            len += 1;
        }
    }
    buf[len] = ']';
    len += 1;
    buf[len] = 0;
    len += 1;

    const color_alt = is_active.*;
    if (color_alt) {
        const cell_bg_color = zgui.colorConvertFloat4ToU32(.{ 0.0, 0.55, 1.0, 1 });
        zgui.tableSetBgColor(.{ .target = .cell_bg, .color = cell_bg_color });
    }

    // const x = zgui.getCursorPosX();
    // const y = zgui.getCursorPosY();
    zgui.labelText("", "{s}", .{buf[0..len]});

    // _ = zgui.button("", .{})) {
    // zgui.button("DelayNone", sz);
    zgui.sameLine(.{});
    // if (zgui.isItemHovered(.{ .delay_none = true })) {
    //     zgui.setCursorPosX(x);
    //     zgui.setCursorPosY(y);

    if (color_alt) {
        zgui.pushStyleColor4f(.{ .idx = .button, .c = .{ 0.0, 0.0, 0.6, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .button_hovered, .c = .{ 0.2, 0.2, 0.8, 1.0 } });
        zgui.pushStyleColor4f(.{ .idx = .button_active, .c = .{ 0.4, 0.4, 1.0, 1.0 } });
    }
    if (zgui.button("#", .{})) {
        is_active.* = !is_active.*;
    }
    if (color_alt) {
        zgui.popStyleColor(.{ .count = 3 });
    }
    if (is_active.*) {
        return column.datatype.subtable.table;
    }
    return null;
}

pub const ColumnReference = struct {
    self_column: *const Column,
    table: *Table,
    column: *Column,
    default: ?u32 = null,

    pub fn getContent(self: ColumnReference, i_row: usize) ?u32 {
        const celldata = self.self_column.data.slice()[i_row];
        const ref_i_row_opt: *?u32 = @alignCast(std.mem.bytesAsValue(?u32, celldata));
        return ref_i_row_opt.*;
    }

    pub fn getContentPtr(self: *ColumnReference, i_row: usize) *?u32 {
        const celldata = self.self_column.data.slice()[i_row];
        const ref_i_row_opt: *?u32 = @alignCast(std.mem.bytesAsValue(?u32, celldata));
        return ref_i_row_opt;
    }

    pub fn toBuf(self: ColumnReference, i_row: usize, buf: []u8) usize {
        const celldata = self.self_column.data.slice()[i_row];
        const ref_i_row_opt: *?u32 = @alignCast(std.mem.bytesAsValue(?u32, celldata));
        if (ref_i_row_opt.*) |ref_i_row| {
            return self.column.toBuf(ref_i_row, buf);
        } else {
            const str = std.fmt.bufPrintZ(buf, "<Null>", .{}) catch unreachable;
            return std.mem.indexOfSentinel(u8, 0, @ptrCast(str));
        }
    }
};

pub const ColumnSubTable = struct {
    self_column: *const Column,
    table: *Table,
    // column: *Column,
    // default: u32 = 0,

    pub fn toBuf(self: ColumnSubTable, i_row: usize, buf: []u8) usize {
        _ = self; // autofix
        _ = i_row; // autofix
        const str = std.fmt.bufPrint(buf, "TABLE", .{}) catch unreachable;
        return str.len;
    }
};

pub const ColumnType = union(enum) {
    integer: column_integer.ColumnInteger,
    text: column_text.ColumnText,
    reference: ColumnReference,
    subtable: ColumnSubTable,
};

pub const ColumnTypeAPI = extern struct {
    name: [*:0]const u8 = "",
    elem_size: u32,

    toBuf: ?*const fn (self: *const Column, i_row: usize, buf: [*]u8, bufLen: u64) callconv(.C) usize = null,
    getContentPtr: ?*const fn (self: *Column, i_row: usize) callconv(.C) ?[*]u8 = null,
};

pub var column_type_registry: ColumnTypeRegistry = undefined;
pub var plugin_api: plugin_common.PluginApi = undefined;

fn plugin_allocPermanent(size: usize) callconv(.C) [*]u8 {
    const ptr = std.heap.c_allocator.alignedAlloc(u8, 8, size) catch unreachable;
    return ptr.ptr;
}

pub fn registerColumnTypes() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    plugin_api = .{
        .allocPermanent = plugin_allocPermanent,
    };
    column_type_registry.init(gpa.allocator());
    column_type_registry.registerColumnType(column_text.getColumnType(&plugin_api));
    column_type_registry.registerColumnType(column_integer.getColumnType(&plugin_api));
}

var dummy_api = ColumnTypeAPI{
    .elem_size = undefined,
    .self_data = undefined,
};

pub const Column = struct {
    name: std.BoundedArray(u8, 128) = .{},
    owner_table: *Table,
    visible: bool = true,
    datatype: ColumnType,
    api: *const ColumnTypeAPI = &dummy_api,
    data: std.BoundedArray([]u8, ROW_COUNT) = .{},

    pub fn getContentPtr(self: *Column, i_row: usize, T: type) *T {
        const ptr: *T = @alignCast(@ptrCast(self.api.getContentPtr.?(self, i_row)));
        return ptr;
    }

    pub fn toBuf(self: Column, i_row: usize, buf: []u8) usize {
        if (self.api.toBuf) |toBufFn| {
            return toBufFn(&self, i_row, buf.ptr, buf.len);
        }

        switch (self.datatype) {
            .reference => {
                return self.datatype.reference.toBuf(i_row, buf);
            },
            .subtable => {
                return self.datatype.subtable.toBuf(i_row, buf);
            },
            else => unreachable,
        }
        return self.column.toBuf(i_row, buf);
    }

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
                    i_row.* = @intCast(self.data.len);
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
                const i_row = allocator.create(?u32) catch unreachable;
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
    uid: usize = 0,

    pub fn init(self: *Table, name: []const u8, allocator: std.mem.Allocator) void {
        self.* = .{
            .name = std.BoundedArray(u8, 128).fromSlice(name) catch unreachable,
            .allocator = allocator,
            .subtables = std.ArrayList(*Table).initCapacity(allocator, 4) catch unreachable,
        };

        const column = self.columns.addOneAssumeCapacity();
        column.* = .{
            .name = std.BoundedArray(u8, 128).fromSlice("PK") catch unreachable,
            .owner_table = self,
            .datatype = .{ .integer = .{
                .is_primary_key = true,
                .min = 0,
                .self_column = column,
            } },
            .visible = true,
        };
    }

    pub fn addRow(self: *Table) void {
        self.row_count += 1;
        for (self.columns.slice()) |*column| {
            column.addRow(self.allocator);
        }
    }

    pub fn deleteRow(self: *Table, i_row: usize, all_tables: []*Table) void {
        std.debug.print("deleteRow {s}::{d}\n", .{ self.name.slice(), i_row });
        for (self.columns.slice()) |*column| {
            if (column.datatype == .subtable) {
                const table = column.datatype.subtable.table;
                var fk_column = table.getColumn("FK").?.datatype.reference;
                const table_row_count = table.row_count; // Gotta store first.
                for (1..table_row_count) |i_row2| {
                    const i_row_reverse = table_row_count - i_row2;
                    const fk = fk_column.getContent(i_row_reverse).?;
                    if (fk == i_row) {
                        table.deleteRow(i_row_reverse, all_tables);
                    }
                }
            }
        }

        // TODO: Deallocate
        for (all_tables) |table| {
            for (table.columns.slice()) |*column| {
                if (column.datatype == .reference) {
                    if (column.datatype.reference.table != self) {
                        continue;
                    }

                    for (1..table.row_count) |i_row2| {
                        const line_ref_opt: *?u32 = column.datatype.reference.getContentPtr(i_row2);
                        if (line_ref_opt.* == @as(u32, @intCast(i_row))) {
                            std.debug.print("  deref {s}::{d} for {d}\n", .{ table.name.slice(), i_row2, i_row });
                            line_ref_opt.* = null;
                        }
                    }
                }
            }
        }

        for (self.columns.slice()) |*column| {
            if (column.datatype == .subtable) {
                const table = column.datatype.subtable.table;
                var fk_column = table.getColumn("FK").?.datatype.reference;
                for (1..table.row_count) |i_row2| {
                    const fk = fk_column.getContentPtr(i_row2);
                    if (fk.*.? > i_row) {
                        std.debug.print("  sub {s}::{d} at {d}\n", .{ table.name.slice(), i_row2, fk.*.? });
                        fk.*.? -= 1;
                    }
                }
            }
        }

        for (self.columns.slice()) |*column| {
            _ = column.data.orderedRemove(i_row);
        }
        self.row_count -= 1;

        for (i_row..self.row_count) |i_row2| {
            const pk: *i64 = self.columns.buffer[0].getContentPtr(i_row2, i64);
            pk.* -= 1;
            std.debug.assert(pk.* > 0);
        }
    }

    pub fn visibleColumnCount(self: Table) i32 {
        var count: i32 = 0;
        for (self.columns.slice()) |column| {
            _ = column; // autofix
            // if (column.visible) {
            count += 1;
            // }
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

    pub fn getColumnConst(self: *const Table, name: []const u8) ?*const Column {
        for (self.columns.slice()) |*column| {
            if (std.mem.eql(u8, name, column.name.slice())) {
                return column;
            }
        }

        return null;
    }
};
