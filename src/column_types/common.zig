const std = @import("std");

const t = @import("../table.zig");

pub const PluginApi = struct {
    alloc: *const fn (usize) callconv(.C) [*]u8,
};

pub fn alloc(plugin_api: *PluginApi, T: type) *T {
    const bytes = plugin_api.alloc(@sizeOf(T));
    const ptr: *T = @alignCast(std.mem.bytesAsValue(T, bytes));
    return ptr;
}

pub fn getContentPtr(api: t.ColumnTypeAPI, i_row: usize, T: type) *T {
    const ptr: *T = @ptrCast(api.getContentPtr(i_row));
    return ptr;
}
