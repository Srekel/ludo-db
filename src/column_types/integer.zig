const std = @import("std");
const zgui = @import("zgui");

const common = @import("common.zig");
const t = @import("../table.zig");

pub const ColumnInteger = struct {
    self_column: *const t.Column,
    default: i64 = 0,
    min: i64 = std.math.minInt(i64),
    max: i64 = std.math.maxInt(i64),
    is_primary_key: bool = false,
};

pub fn create(column: *t.Column) callconv(.C) [*]u8 {
    const data = common.allocPermanent(column.api.plugin_api, ColumnInteger);
    data.* = .{
        .self_column = column,
    };
    return @ptrCast(data);
}

pub fn draw(self: *const t.Column, i_row: usize) callconv(.C) usize {
    const celldata = self.data.slice()[i_row];
    const config: *const ColumnInteger = @alignCast(std.mem.bytesAsValue(ColumnInteger, self.config));
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
    return 0;
}

pub fn getContent(self: ColumnInteger, i_row: usize) i64 {
    const celldata = self.data.slice()[i_row];
    const int: *i64 = @alignCast(std.mem.bytesAsValue(i64, celldata));
    return int.*;
}

pub fn getContentPtr(self: *t.Column, i_row: usize) callconv(.C) ?[*]u8 {
    const celldata = self.data.slice()[i_row];
    const int: *i64 = @alignCast(std.mem.bytesAsValue(i64, celldata));
    return std.mem.asBytes(int);
}

pub fn toBuf(self: *const t.Column, i_row: usize, buf_ptr: [*]u8, buf_len: u64) callconv(.C) usize {
    const buf = buf_ptr[0..buf_len];
    const celldata = self.data.slice()[i_row];
    const int: *i64 = @alignCast(std.mem.bytesAsValue(i64, celldata));
    const int_str = std.fmt.bufPrint(buf, "{d}", .{int.*}) catch unreachable;
    return int_str.len;
}

pub fn getColumnType(plugin_api: *common.PluginApi) t.ColumnTypeAPI {
    return .{
        .name = "integer",
        .elem_size = @sizeOf(i64),
        .plugin_api = plugin_api,
        .create = create,
        .draw = draw,
        .getContentPtr = getContentPtr,
        .toBuf = toBuf,
    };
}
