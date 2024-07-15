const std = @import("std");
const fs = std.fs;

const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");

const save = @import("json_format.zig");

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

    const window = try zglfw.Window.create(900, 600, window_title, null);
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

    try initProject(gpa);
    var project_tables = std.ArrayList(*t.Table).initCapacity(gpa, 128) catch unreachable;
    save.loadProject(&project_tables, gpa) catch unreachable;

    var window_uid: u32 = 0;
    for (project_tables.items) |table| {
        window_uid = @max(window_uid, table.uid) + 1;
    }

    var show_demo = false;
    var last_focused_window: ?*t.Table = null;
    var renaming = false;

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();

        zgui.backend.newFrame(
            gctx.swapchain_descriptor.width,
            gctx.swapchain_descriptor.height,
        );

        // Set the starting window position and size to custom values
        // zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
        // zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });
        if (zgui.beginMainMenuBar()) {
            if (zgui.beginMenu("Save", true)) {
                save.exportProject(project_tables.items) catch unreachable;
                zgui.endMenu();
            }
            if (zgui.beginMenu("Load", true)) {
                project_tables.resize(0) catch unreachable;
                save.loadProject(&project_tables, gpa) catch unreachable;
                zgui.endMenu();
            }
            if (zgui.beginMenu("(imgui demo)", true)) {
                show_demo = !show_demo; // TODO
                zgui.endMenu();
            }
            if (zgui.beginMenu("[+] New Table", true)) {
                var name_index = project_tables.items.len;
                var buf: [1024 * 4]u8 = undefined;
                var table_name = std.fmt.bufPrintZ(&buf, "untitled_table_{d}", .{name_index}) catch unreachable;
                while (true) {
                    for (project_tables.items) |table_tmp| {
                        if (std.mem.eql(u8, table_tmp.name.slice(), table_name)) {
                            name_index += 1;
                            table_name = std.fmt.bufPrintZ(&buf, "untitled_table_{d}", .{name_index}) catch unreachable;
                            break;
                        }
                    } else {
                        break;
                    }
                }

                const table: *t.Table = gpa.create(t.Table) catch unreachable;
                table.* = .{
                    .name = std.BoundedArray(u8, 128).fromSlice(table_name) catch unreachable,
                    .allocator = gpa,
                    .subtables = std.ArrayList(*t.Table).initCapacity(gpa, 4) catch unreachable,
                    .is_subtable = false,
                };
                {
                    const column: t.Column = .{
                        .name = std.BoundedArray(u8, 128).fromSlice("id") catch unreachable,
                        .owner_table = table,
                        .datatype = .{ .text = .{} },
                    };
                    table.columns.appendAssumeCapacity(column);
                }
                project_tables.appendAssumeCapacity(table);
                zgui.endMenu();
            }
            zgui.endMainMenuBar();
        }

        for (project_tables.items) |table| {
            if (!table.is_subtable) {
                var buf: [1024 * 4]u8 = undefined;
                const table_name = std.fmt.bufPrintZ(&buf, "{s}###{d}", .{ table.name.slice(), table.uid }) catch unreachable;
                if (zgui.begin(table_name, .{})) {
                    if (zgui.isWindowFocused(.{})) {
                        last_focused_window = table;
                    }
                    if (last_focused_window == table and zgui.beginMainMenuBar()) {
                        if (zgui.beginMenu(@ptrCast(table.name.slice()), true)) {
                            if (zgui.menuItem("Rename", .{})) {
                                renaming = true;
                            }
                            if (zgui.menuItem("Add row", .{})) {
                                table.addRow();
                            }
                            if (zgui.menuItem("Add text column", .{})) {
                                var column: t.Column = .{
                                    .name = std.BoundedArray(u8, 128).fromSlice("text") catch unreachable,
                                    .owner_table = table,
                                    .datatype = .{ .text = .{} },
                                };
                                for (0..table.row_count) |_| {
                                    column.addRow(table.allocator);
                                }
                                table.columns.appendAssumeCapacity(column);
                            }
                            if (zgui.menuItem("Add reference column", .{})) {
                                var column: t.Column = .{
                                    .name = std.BoundedArray(u8, 128).fromSlice("ref") catch unreachable,
                                    .owner_table = table,
                                    .datatype = .{ .reference = .{
                                        .table = project_tables.items[0],
                                        .column = &project_tables.items[0].columns.buffer[0],
                                    } },
                                };
                                for (0..table.row_count) |_| {
                                    column.addRow(table.allocator);
                                }
                                table.columns.appendAssumeCapacity(column);
                            }
                            zgui.endMenu();
                        }
                        zgui.endMainMenuBar();
                    }
                    doTable(table, 0, .{}, null);
                }
                zgui.end();
            }
        }

        if (renaming) {
            zgui.openPopup("Nametable?", .{});
            renaming = false;
        }
        if (zgui.beginPopupModal("Nametable?", .{ .flags = .{ .always_auto_resize = true } })) {
            _ = zgui.inputText(
                "##renameinput",
                .{ .buf = @ptrCast(&last_focused_window.?.name.buffer) },
            );
            last_focused_window.?.name.len = @intCast(std.mem.indexOfSentinel(u8, 0, @ptrCast(&last_focused_window.?.name.buffer)));
            zgui.setItemDefaultFocus();

            if (zgui.button("OK", .{})) {
                zgui.closeCurrentPopup();
            }
            zgui.endPopup();
        }

        if (show_demo) {
            zgui.showDemoWindow(null);
        }

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

const Filter = struct {
    fk: ?usize = null,
};

const show_row = false;

fn doTable(
    table: *t.Table,
    start_row: usize,
    filter: Filter,
    parent_row: ?usize,
) void {
    if (table.columns.slice().len == 0) {
        return;
    }
    if (zgui.beginTable(@ptrCast(table.name.slice()), .{
        .column = table.visibleRowCount() + if (show_row) 1 else 0,
        .flags = .{
            .resizable = true,
            .row_bg = true,
            .borders = zgui.TableBorderFlags.all,
        },
    })) {
        // Headers
        if (show_row) {
            zgui.tableSetupColumn("Row", .{ .flags = .{
                .width_fixed = true,
            } });
        }

        for (table.columns.slice()) |column| {
            if (!column.visible) {
                continue;
            }
            _ = zgui.tableSetupColumn(@ptrCast(column.name.slice()), .{
                .flags = .{
                    .width_stretch = true,
                    // .disabled = !column.visible,
                },
            });
        }

        zgui.tableHeadersRow();

        var table_active = true;
        for (start_row..table.row_count) |i_row| {
            if (filter.fk) |filter_fk| {
                const column = table.getColumn("FK").?;
                const column_fk: *u32 = @alignCast(std.mem.bytesAsValue(u32, column.data.slice()[i_row]));
                if (filter_fk != column_fk.*) {
                    continue;
                }
            }
            if (!table_active) {
                table_active = true;
                _ = zgui.beginTable(@ptrCast(table.name.slice()), .{
                    .column = table.visibleRowCount() + if (show_row) 1 else 0,
                    .flags = .{
                        .resizable = true,
                        .borders = zgui.TableBorderFlags.all,
                    },
                });
            }

            zgui.tableNextRow(.{});
            zgui.pushIntId(@intCast(i_row));

            if (show_row) {
                _ = zgui.tableSetColumnIndex(@intCast(0));
                zgui.labelText("##row", "{d}", .{i_row});
            }

            var subtable_opt: ?*t.Table = null;
            var i_col: usize = if (show_row) 0 else std.math.maxInt(usize);
            for (table.columns.slice()) |column| {
                if (!column.visible) {
                    continue;
                }
                i_col +%= 1;
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
                const x = zgui.getCursorPosX();
                zgui.setCursorPosX(x + 30);
                doTable(subtable, 0, .{ .fk = i_row }, i_row);
                zgui.setCursorPosX(x);
            }
        }
        if (table_active) {
            zgui.tableNextRow(.{});
            _ = zgui.tableSetColumnIndex(0);
            if (zgui.button("[+]", .{})) {
                table.addRow();

                if (parent_row) |fk| {
                    const column = table.getColumn("FK").?;
                    const column_fk: *u32 = column.getRowAs(column.data.slice().len - 1, u32);
                    column_fk.* = @intCast(fk);
                }
            }
            zgui.endTable();
        }
    }
}

pub fn initProject(allocator: std.mem.Allocator) !void {
    var buf: [1024 * 4]u8 = undefined;
    const project_json = try std.fs.cwd().readFile("ludo_db.config.json", &buf);

    const j_root = try std.json.parseFromSlice(std.json.Value, allocator, project_json, .{});
    defer j_root.deinit();

    const folder_rel_path = j_root.value.object.get("project_folder").?.string;
    var dir = try std.fs.cwd().openDir(folder_rel_path, .{});
    defer dir.close();

    try dir.setAsCwd();
}
