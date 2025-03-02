const std = @import("std");

const t = @import("../table.zig");

pub const PluginApi = struct {
    allocPermanent: *const fn (usize) callconv(.C) [*]u8,
};

pub fn allocPermanent(plugin_api: *PluginApi, T: type) *T {
    const bytes = plugin_api.allocPermanent(@sizeOf(T));
    const ptr: *T = @alignCast(std.mem.bytesAsValue(T, bytes));
    return ptr;
}

pub fn getContentPtr(column: *t.Column, i_row: usize, T: type) *T {
    const ptr: *T = @ptrCast(column.api.getContentPtr.?(column, i_row));
    return ptr;
}
