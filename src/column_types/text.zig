const std = @import("std");
const zgui = @import("zgui");

const t = @import("../table.zig");
const plugin = @import("common.zig");

pub const ColumnText = struct {
    self_column: *t.Column,
    default: [:0]const u8 = "",
    text_len: u32 = 32,
};

pub fn toBuf(self: *const t.Column, i_row: usize, buf_ptr: [*]u8, buf_len: u64) callconv(.C) usize {
    const buf = buf_ptr[0..buf_len];
    const celldata = self.data.slice()[i_row];
    const str = std.fmt.bufPrint(buf, "{s}", .{celldata}) catch unreachable;
    return std.mem.indexOfSentinel(u8, 0, @ptrCast(str));
}

pub fn create(column: *t.Column) callconv(.C) [*]u8 {
    const data = plugin.allocPermanent(column.api.plugin_api, ColumnText);
    data.* = .{
        .self_column = column,
    };
    return @ptrCast(data);
}

pub fn getColumnType(plugin_api: *plugin.PluginApi) t.ColumnTypeAPI {
    return .{
        .name = "text",
        .plugin_api = plugin_api,
        .create = create,
        .elem_size = @sizeOf(usize),
        .toBuf = toBuf,
    };
}
