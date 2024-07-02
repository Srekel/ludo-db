const std = @import("std");

const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");

const t = @import("table.zig");

const window_title = "Ludo DB";

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    zglfw.windowHintTyped(.client_api, .no_api);

    const window = try zglfw.Window.create(800, 500, window_title, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const gctx = try zgpu.GraphicsContext.create(
        gpa,
        .{
            .window = window,
            .fn_getTime = @ptrCast(&zglfw.getTime),
            .fn_getFramebufferSize = @ptrCast(&zglfw.Window.getFramebufferSize),
            .fn_getWin32Window = @ptrCast(&zglfw.getWin32Window),
            .fn_getX11Display = @ptrCast(&zglfw.getX11Display),
            .fn_getX11Window = @ptrCast(&zglfw.getX11Window),
            .fn_getWaylandDisplay = @ptrCast(&zglfw.getWaylandDisplay),
            .fn_getWaylandSurface = @ptrCast(&zglfw.getWaylandWindow),
            .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
        },
        .{},
    );
    defer gctx.destroy(gpa);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    zgui.init(gpa);
    defer zgui.deinit();

    _ = zgui.io.addFontFromFile(
        "Roboto-Medium.ttf",
        std.math.floor(16.0 * scale_factor),
    );

    zgui.backend.init(
        window,
        gctx.device,
        @intFromEnum(zgpu.GraphicsContext.swapchain_format),
        @intFromEnum(wgpu.TextureFormat.undef),
    );
    defer zgui.backend.deinit();

    zgui.getStyle().scaleAllSizes(scale_factor);

    var table_category: t.Table = .{
        .name = std.BoundedArray(u8, 128).fromSlice("category") catch unreachable,
        .allocator = gpa,
        .subtables = std.ArrayList(t.Table).initCapacity(gpa, 4) catch unreachable,
    };
    {
        const column: t.Column = .{
            .name = std.BoundedArray(u8, 128).fromSlice("category") catch unreachable,
            .owner_table = &table_category,
            .datatype = .{ .text = .{} },
        };
        table_category.columns.appendAssumeCapacity(column);
    }
    {
        const column: t.Column = .{
            .name = std.BoundedArray(u8, 128).fromSlice("parent") catch unreachable,
            .owner_table = &table_category,
            .datatype = .{ .reference = .{
                .table = &table_category,
                .column = &table_category.columns.slice()[0],
            } },
        };
        table_category.columns.appendAssumeCapacity(column);
    }
    {
        const subtable = table_category.subtables.addOneAssumeCapacity();
        subtable.* = .{
            .name = std.BoundedArray(u8, 128).fromSlice("sub") catch unreachable,
            .allocator = gpa,
            .subtables = std.ArrayList(t.Table).init(gpa),
        };
        const column: t.Column = .{
            .name = std.BoundedArray(u8, 128).fromSlice("parents") catch unreachable,
            .owner_table = &table_category,
            .datatype = .{ .subtable = .{
                .table = subtable,
            } },
        };
        table_category.columns.appendAssumeCapacity(column);
        const subcolumn_fk: t.Column = .{
            .name = std.BoundedArray(u8, 128).fromSlice("FK") catch unreachable,
            .owner_table = subtable,
            .datatype = .{ .reference = .{
                .table = &table_category,
                .column = &table_category.columns.slice()[0],
            } },
        };
        subtable.columns.appendAssumeCapacity(subcolumn_fk);
    }

    table_category.addRow();
    table_category.addRow();
    table_category.addRow();
    table_category.addRow();

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();

        zgui.backend.newFrame(
            gctx.swapchain_descriptor.width,
            gctx.swapchain_descriptor.height,
        );

        // Set the starting window position and size to custom values
        zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
        zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

        if (zgui.begin("My window", .{})) {
            if (zgui.button("Press me!", .{ .w = 200.0 })) {
                std.debug.print("Button pressed\n", .{});
            }
        }

        doTable(&table_category, 0);
        zgui.showDemoWindow(null);

        zgui.end();

        const swapchain_texv = gctx.swapchain.getCurrentTextureView();
        defer swapchain_texv.release();

        const commands = commands: {
            const encoder = gctx.device.createCommandEncoder(null);
            defer encoder.release();

            // GUI pass
            {
                const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
                defer zgpu.endReleasePass(pass);
                zgui.backend.draw(pass);
            }

            break :commands encoder.finish(null);
        };
        defer commands.release();

        gctx.submit(&.{commands});
        _ = gctx.present();
    }
}

fn doTable(table: *t.Table, start_row: usize) void {
    if (zgui.beginTable(@ptrCast(table.name.slice()), .{
        .column = table.columns.len + 1,
        .flags = .{
            .resizable = true,
            .borders = zgui.TableBorderFlags.all,
        },
    })) {
        zgui.tableNextRow(.{});
        _ = zgui.tableSetColumnIndex(@intCast(0));
        zgui.labelText("", "Row", .{});
        for (table.columns.slice(), 1..) |column, i_col| {
            _ = zgui.tableSetColumnIndex(@intCast(i_col));
            zgui.labelText("", "{s}", .{column.name.slice()});
        }
        var table_active = true;
        for (start_row..table.row_count) |i_row| {
            if (!table_active) {
                table_active = true;
                _ = zgui.beginTable(@ptrCast(table.name.slice()), .{ .column = table.columns.len, .flags = .{
                    .resizable = true,
                    .borders = zgui.TableBorderFlags.all,
                } });
            }
            zgui.tableNextRow(.{});
            zgui.pushIntId(@intCast(i_row));

            _ = zgui.tableSetColumnIndex(@intCast(0));
            zgui.labelText("##row", "{d}", .{i_row});

            var subtable_opt: ?*t.Table = null;
            for (table.columns.slice(), 1..) |column, i_col| {
                zgui.pushIntId(@intCast(i_col));
                _ = zgui.tableSetColumnIndex(@intCast(i_col));
                const subtable_opt_temp = t.drawElement(table.*, column, i_row);

                if (subtable_opt_temp) |subtable| {
                    subtable_opt = subtable;
                }
                zgui.popId();
            }

            zgui.popId();
            if (subtable_opt) |subtable| {
                table_active = false;
                zgui.endTable();
                doTable(subtable, 0);
            }
        }
        if (table_active) {
            zgui.tableNextRow(.{});
            _ = zgui.tableSetColumnIndex(0);
            if (zgui.button("[+]", .{})) {
                table.addRow();
            }
            zgui.endTable();
        }
    }
}
