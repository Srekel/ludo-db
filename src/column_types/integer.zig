const std = @import("std");
const zgui = @import("zgui");

const t = @import("../table.zig");

pub const ColumnInteger = struct {
    self_column: *const t.Column,
    default: i64 = 0,
    min: i64 = std.math.minInt(i64),
    max: i64 = std.math.maxInt(i64),
    is_primary_key: bool = false,
};

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

pub fn getColumnType() t.ColumnTypeAPI {
    return .{
        .name = "text",
        .elem_size = @sizeOf(i64),
        .toBuf = toBuf,
        .getContentPtr = getContentPtr,
    };
}
