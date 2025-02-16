const std = @import("std");
const zgui = @import("zgui");

const table = @import("../table.zig");

pub const ColumnText = struct {
    self_column: *const table.Column,
    default: [:0]const u8 = "",
    text_len: u32 = 32,

    pub fn toBuf(self: ColumnText, i_row: usize, buf: []u8) usize {
        const celldata = self.self_column.data.slice()[i_row];
        const str = std.fmt.bufPrint(buf, "{s}", .{celldata}) catch unreachable;
        return std.mem.indexOfSentinel(u8, 0, @ptrCast(str));
    }
};

pub fn toBuf(self: ColumnText, i_row: usize, buf: []u8) usize {
    const celldata = self.self_column.data.slice()[i_row];
    const str = std.fmt.bufPrint(buf, "{s}", .{celldata}) catch unreachable;
    return std.mem.indexOfSentinel(u8, 0, @ptrCast(str));
}

pub fn registerColumnType(registry: *table.ColumnTypeRegistry) void {
    registry.registerColumnType("text", .{
        .toBuf = toBuf,
    });
}
