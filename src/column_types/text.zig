const std = @import("std");
const zgui = @import("zgui");

const t = @import("../table.zig");

pub const ColumnText = struct {
    self_column: *const t.Column,
    default: [:0]const u8 = "",
    text_len: u32 = 32,
};

pub fn toBuf(self: *const t.Column, i_row: usize, buf_ptr: [*]u8, buf_len: u64) callconv(.C) usize {
    const buf = buf_ptr[0..buf_len];
    const celldata = self.data.slice()[i_row];
    const str = std.fmt.bufPrint(buf, "{s}", .{celldata}) catch unreachable;
    return std.mem.indexOfSentinel(u8, 0, @ptrCast(str));
}

pub fn getColumnType() t.ColumnTypeAPI {
    return .{
        .name = "text",
        .toBuf = toBuf,
    };
}
