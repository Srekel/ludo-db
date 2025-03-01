const std = @import("std");

pub const PluginApi = struct {
    alloc:*const fn(usize) [*]u8,
};

pub fn alloc(plugin_api:*PluginApi, T:type) *T {
    var bytes = plugin_api.alloc(@sizeOf(T));
    var t:*T = std.mem.bytesAsValue(bytes);
    return t;
}
