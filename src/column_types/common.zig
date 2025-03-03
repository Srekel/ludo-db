const std = @import("std");

pub const PluginApi = extern struct {
    allocPermanent: *const fn (usize) callconv(.C) [*]u8,
};

pub var api: PluginApi = undefined;

// ██╗   ██╗████████╗██╗██╗
// ██║   ██║╚══██╔══╝██║██║
// ██║   ██║   ██║   ██║██║
// ██║   ██║   ██║   ██║██║
// ╚██████╔╝   ██║   ██║███████╗
//  ╚═════╝    ╚═╝   ╚═╝╚══════╝

pub fn allocPermanent(plugin_api: *PluginApi, T: type) *T {
    const bytes = plugin_api.allocPermanent(@sizeOf(T));
    const ptr: *T = @alignCast(std.mem.bytesAsValue(T, bytes));
    return ptr;
}
