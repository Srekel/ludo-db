const std = @import("std");
const fs = std.fs;

const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");

const save = @import("json_format.zig");
const t = @import("table.zig");
const styles = @import("styles.zig");

const window_title = "Ludo DB";
var project_tables: std.ArrayList(*t.Table) = undefined;
var renaming: ?*t.Table = null;

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    zglfw.windowHintTyped(.client_api, .no_api);

    const window = try zglfw.Window.create(1000, 700, window_title, null);
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
    // styles.setupStyle();

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
    project_tables = std.ArrayList(*t.Table).initCapacity(gpa, 128) catch unreachable;
    save.loadProject(&project_tables, gpa) catch unreachable;

    var window_uid: u32 = 0;
    for (project_tables.items) |table| {
        window_uid = @max(window_uid, table.uid) + 1;
    }

    var show_demo = false;

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
                table.init(table_name, gpa);
                {
                    const column = table.columns.addOneAssumeCapacity();
                    column.* = .{
                        .name = std.BoundedArray(u8, 128).fromSlice("id") catch unreachable,
                        .owner_table = table,
                        .datatype = .{ .text = .{
                            .self_column = column,
                        } },
                    };
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
                if (zgui.begin(table_name, .{ .flags = .{
                    .menu_bar = true,
                    .horizontal_scrollbar = true,
                } })) {
                    doTable(table, 0, .{}, null);
                }
                zgui.end();
            }
        }

        if (renaming != null) {
            zgui.openPopup("Rename table", .{});
        }
        if (renaming != null and zgui.beginPopupModal("Rename table", .{ .flags = .{ .always_auto_resize = true } })) {
            _ = zgui.inputText(
                "##renameinput",
                .{ .buf = @ptrCast(&renaming.?.name.buffer) },
            );
            renaming.?.name.len = @intCast(std.mem.indexOfSentinel(u8, 0, @ptrCast(&renaming.?.name.buffer)));
            zgui.setItemDefaultFocus();

            if (zgui.button("OK", .{})) {
                renaming = null;
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
    if (table.visibleColumnCount() == 0) {
        return;
    }

    if (zgui.beginTable(@ptrCast(table.name.slice()), .{
        .column = table.visibleColumnCount() + if (show_row) 1 else 0,
        .flags = .{
            .resizable = true,
            .reorderable = true,
            .hideable = true,
            .context_menu_in_body = true,
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
            // if (!column.visible) {
            //     continue;
            // }
            _ = zgui.tableSetupColumn(@ptrCast(column.name.slice()), .{
                .flags = .{
                    .width_stretch = true,
                    // .disabled = !column.visible,
                },
            });
        }

        // Custom headers
        zgui.tableNextRow(.{ .row_flags = .{ .headers = true } });
        for (table.columns.slice(), 0..) |*column, i_col| {
            _ = zgui.tableSetColumnIndex(@intCast(i_col));
            const column_name = zgui.tableGetColumnName(.{ .column_n = @intCast(i_col) }); // Retrieve name passed to TableSetupColumn()
            _ = column_name; // autofix
            zgui.pushIntId(@intCast(i_col));
            if (zgui.smallButton("..")) {
                zgui.openPopup("column_popup", .{});
            }
            const table_valid = doColumnPopup(column, table);
            // zgui.pushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(0, 0));
            // zgui.popStyleVar();
            // zgui.tableHeader(@ptrCast(column_name[0..]));
            if (!table_valid) {
                zgui.popId();
                zgui.endTable();
                return;
            }

            zgui.sameLine(.{ .offset_from_start_x = 0.0, .spacing = zgui.getStyle().item_inner_spacing[0] });
            zgui.tableHeader(@ptrCast(column.name.slice()));
            zgui.popId();
        }

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
                    .column = table.visibleColumnCount() + if (show_row) 1 else 0,
                    .flags = .{
                        .resizable = true,
                        .borders = zgui.TableBorderFlags.all,
                    },
                });
            }

            zgui.tableNextRow(.{});
            zgui.pushIntId(@intCast(i_row)); // row id

            if (show_row) {
                _ = zgui.tableSetColumnIndex(@intCast(0));
                zgui.labelText("##row", "{d}", .{i_row});
            }

            var subtable_opt: ?*t.Table = null;
            var i_col: usize = if (show_row) 0 else std.math.maxInt(usize);
            for (table.columns.slice()) |column| {
                // if (!column.visible) {
                //     continue;
                // }
                i_col +%= 1;
                zgui.pushIntId(@intCast(i_col));
                defer zgui.popId(); // column id

                _ = zgui.tableSetColumnIndex(@intCast(i_col));
                const subtable_opt_temp = t.drawElement(table.*, column, i_row);

                if (subtable_opt_temp) |subtable| {
                    subtable_opt = subtable;
                }
            }

            zgui.popId(); // row id
            if (subtable_opt) |subtable| {
                if (zgui.beginPopupContextItem()) // <-- use last item id as popup id
                {
                    zgui.text("This is a popup for", .{});
                    if (zgui.button("Close", .{}))
                        zgui.closeCurrentPopup();
                    zgui.endPopup();
                }
                // zgui.setItemTooltip("Right-click to open popup");

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

fn doColumnPopup(column: *t.Column, table: *t.Table) bool {
    var table_valid = true;
    _ = column; // autofix
    if (zgui.beginPopup("column_popup", .{})) {

        // if (zgui.beginMenu("Actions", true)) {
        if (zgui.menuItem("Rename", .{})) {
            renaming = table;
        }

        if (zgui.menuItem("Add integer column", .{})) {
            var column_new = table.columns.addOneAssumeCapacity();
            column_new.* = .{
                .name = std.BoundedArray(u8, 128).fromSlice("integer") catch unreachable,
                .owner_table = table,
                .datatype = .{ .integer = .{
                    .self_column = column_new,
                } },
            };
            for (0..table.row_count) |_| {
                column_new.addRow(table.allocator);
            }
            table_valid = false;
        }

        if (zgui.menuItem("Add text column_new", .{})) {
            var column_new = table.columns.addOneAssumeCapacity();
            column_new.* = .{
                .name = std.BoundedArray(u8, 128).fromSlice("text") catch unreachable,
                .owner_table = table,
                .datatype = .{ .text = .{
                    .self_column = column_new,
                } },
            };
            for (0..table.row_count) |_| {
                column_new.addRow(table.allocator);
            }
            table_valid = false;
        }

        if (zgui.menuItem("Add reference column_new", .{})) {
            var column_new = table.columns.addOneAssumeCapacity();
            column_new.* = .{
                .name = std.BoundedArray(u8, 128).fromSlice("ref") catch unreachable,
                .owner_table = table,
                .datatype = .{ .reference = .{
                    .self_column = column_new,
                    .table = project_tables.items[0],
                    .column = &project_tables.items[0].columns.buffer[0],
                } },
            };
            for (0..table.row_count) |_| {
                column_new.addRow(table.allocator);
            }
            table_valid = false;
        }

        if (zgui.menuItem("Add list column_new", .{})) {
            const subtable = table.allocator.create(t.Table) catch unreachable;
            subtable.* = .{
                .name = std.BoundedArray(u8, 128).fromSlice("Categories::parents") catch unreachable,
                .allocator = table.allocator,
                .subtables = std.ArrayList(*t.Table).init(table.allocator),
            };
            table.subtables.appendAssumeCapacity(subtable);

            const column_new = table.columns.addOneAssumeCapacity();
            column_new.* = .{
                .name = std.BoundedArray(u8, 128).fromSlice("parents") catch unreachable,
                .owner_table = table,
                .datatype = .{ .subtable = .{
                    .self_column = column_new,
                    .table = subtable,
                } },
            };
            for (0..table.row_count) |_| {
                column_new.addRow(table.allocator);
            }

            const subcolumn_fk = subtable.columns.addOneAssumeCapacity();
            subcolumn_fk.* = .{
                .name = std.BoundedArray(u8, 128).fromSlice("FK") catch unreachable,
                .owner_table = subtable,
                .visible = false,
                .datatype = .{ .reference = .{
                    .self_column = subcolumn_fk,
                    .table = table,
                    .column = &table.columns.slice()[0],
                } },
            };

            const subcolumn_id = subtable.columns.addOneAssumeCapacity();
            subcolumn_id.* = .{
                .name = std.BoundedArray(u8, 128).fromSlice("id") catch unreachable,
                .owner_table = table,
                .datatype = .{ .text = .{
                    .self_column = column_new,
                } },
            };
            table_valid = false;
        }

        if (zgui.beginMenu("Delete Table", true)) {
            if (zgui.beginMenu("Confirm", true)) {
                if (zgui.menuItem("Super Confirm!", .{})) {
                    for (table.columns.slice()) |column_tmp| {
                        if (column_tmp.datatype == .subtable) {
                            for (project_tables.items, 0..) |subtable_match, i_stm| {
                                if (column_tmp.datatype.subtable.table == subtable_match) {
                                    const subtable = project_tables.swapRemove(i_stm);
                                    table.allocator.destroy(subtable);
                                    break;
                                }
                            }
                        }
                    }

                    for (project_tables.items, 0..) |table_match, i_tm| {
                        if (table == table_match) {
                            _ = project_tables.swapRemove(i_tm);
                            table.allocator.destroy(table);
                            table_valid = false;
                            break;
                        }
                    }
                }
                zgui.endMenu();
            }
            zgui.endMenu();
        }

        // zgui.endMenu();
        // }

        zgui.endPopup();
    }

    return table_valid;
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
