//
// Based on
// https://github.com/GraphicsProgramming/dear-imgui-styles?tab=readme-ov-file
// https://github.com/adobe/imgui/blob/master/imgui_SpectrumStyle.h
//

const zgui = @import("zgui");

const LudoStyle = struct {
    const CHECKBOX_BORDER_SIZE = 2.0;
    const CHECKBOX_ROUNDING = 2.0;

    pub fn Color(c: u32) u32 {
        const a: u32 = 0xFF;
        const r: u32 = (c >> 16) & 0xFF;
        const g: u32 = (c >> 8) & 0xFF;
        const b: u32 = (c >> 0) & 0xFF;
        return (a << 24) | (r << 0) | (g << 8) | (b << 16);
    }

    const NONE: u32 = 0x00000000; // transparent
    const WHITE: u32 = Color(0xFFFFFF);
    const BLACK: u32 = Color(0x000000);

    const GRAY50: u32 = Color(0xFFFFFF);
    const GRAY75: u32 = Color(0xFAFAFA);
    const GRAY100: u32 = Color(0xF5F5F5);
    const GRAY200: u32 = Color(0xEAEAEA);
    const GRAY300: u32 = Color(0xE1E1E1);
    const GRAY400: u32 = Color(0xCACACA);
    const GRAY500: u32 = Color(0xB3B3B3);
    const GRAY600: u32 = Color(0x8E8E8E);
    const GRAY700: u32 = Color(0x707070);
    const GRAY800: u32 = Color(0x4B4B4B);
    const GRAY900: u32 = Color(0x2C2C2C);
    const BLUE50: u32 = Color(0xA0F0FD);
    const BLUE75: u32 = Color(0x80C0FC);
    const BLUE100: u32 = Color(0x50B0FB);
    const BLUE200: u32 = Color(0x3090FB);
    const BLUE400: u32 = Color(0x2680EB);
    const BLUE500: u32 = Color(0x1473E6);
    const BLUE600: u32 = Color(0x0D66D0);
    const BLUE700: u32 = Color(0x095ABA);
    const RED400: u32 = Color(0xE34850);
    const RED500: u32 = Color(0xD7373F);
    const RED600: u32 = Color(0xC9252D);
    const RED700: u32 = Color(0xBB121A);
    const ORANGE400: u32 = Color(0xE68619);
    const ORANGE500: u32 = Color(0xDA7B11);
    const ORANGE600: u32 = Color(0xCB6F10);
    const ORANGE700: u32 = Color(0xBD640D);
    const GREEN400: u32 = Color(0x2D9D78);
    const GREEN500: u32 = Color(0x268E6C);
    const GREEN600: u32 = Color(0x12805C);
    const GREEN700: u32 = Color(0x107154);
    const INDIGO400: u32 = Color(0x6767EC);
    const INDIGO500: u32 = Color(0x5C5CE0);
    const INDIGO600: u32 = Color(0x5151D3);
    const INDIGO700: u32 = Color(0x4646C6);
    const CELERY400: u32 = Color(0x44B556);
    const CELERY500: u32 = Color(0x3DA74E);
    const CELERY600: u32 = Color(0x379947);
    const CELERY700: u32 = Color(0x318B40);
    const MAGENTA400: u32 = Color(0xD83790);
    const MAGENTA500: u32 = Color(0xCE2783);
    const MAGENTA600: u32 = Color(0xBC1C74);
    const MAGENTA700: u32 = Color(0xAE0E66);
    const YELLOW400: u32 = Color(0xDFBF00);
    const YELLOW500: u32 = Color(0xD2B200);
    const YELLOW600: u32 = Color(0xC4A600);
    const YELLOW700: u32 = Color(0xB79900);
    const FUCHSIA400: u32 = Color(0xC038CC);
    const FUCHSIA500: u32 = Color(0xB130BD);
    const FUCHSIA600: u32 = Color(0xA228AD);
    const FUCHSIA700: u32 = Color(0x93219E);
    const SEAFOAM400: u32 = Color(0x1B959A);
    const SEAFOAM500: u32 = Color(0x16878C);
    const SEAFOAM600: u32 = Color(0x0F797D);
    const SEAFOAM700: u32 = Color(0x096C6F);
    const CHARTREUSE400: u32 = Color(0x85D044);
    const CHARTREUSE500: u32 = Color(0x7CC33F);
    const CHARTREUSE600: u32 = Color(0x73B53A);
    const CHARTREUSE700: u32 = Color(0x6AA834);
    const PURPLE400: u32 = Color(0x9256D9);
    const PURPLE500: u32 = Color(0x864CCC);
    const PURPLE600: u32 = Color(0x7A42BF);
    const PURPLE700: u32 = Color(0x6F38B1);
};

pub fn setupStyle() void {
    var style = zgui.getStyle();
    style.grab_rounding = 4.0;

    var colors = &style.colors;
    colors[@intFromEnum(zgui.StyleCol.text)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY800);
    colors[@intFromEnum(zgui.StyleCol.text_disabled)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY500);
    colors[@intFromEnum(zgui.StyleCol.window_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY100);
    colors[@intFromEnum(zgui.StyleCol.child_bg)] = .{ 0.00, 0.00, 0.00, 0.00 };
    colors[@intFromEnum(zgui.StyleCol.child_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY100);
    colors[@intFromEnum(zgui.StyleCol.popup_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY50);
    colors[@intFromEnum(zgui.StyleCol.border)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY300);
    colors[@intFromEnum(zgui.StyleCol.border_shadow)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY600);
    colors[@intFromEnum(zgui.StyleCol.frame_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY75);
    colors[@intFromEnum(zgui.StyleCol.frame_bg_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE200);
    colors[@intFromEnum(zgui.StyleCol.frame_bg_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE400);
    colors[@intFromEnum(zgui.StyleCol.title_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY300);
    colors[@intFromEnum(zgui.StyleCol.title_bg_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY200);
    colors[@intFromEnum(zgui.StyleCol.title_bg_collapsed)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY400);
    colors[@intFromEnum(zgui.StyleCol.menu_bar_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY100);
    colors[@intFromEnum(zgui.StyleCol.scrollbar_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY100);
    colors[@intFromEnum(zgui.StyleCol.scrollbar_grab)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY500);
    colors[@intFromEnum(zgui.StyleCol.scrollbar_grab_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE400);
    colors[@intFromEnum(zgui.StyleCol.scrollbar_grab_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE75);
    colors[@intFromEnum(zgui.StyleCol.check_mark)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE500);
    colors[@intFromEnum(zgui.StyleCol.slider_grab)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY700);
    colors[@intFromEnum(zgui.StyleCol.slider_grab_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY800);
    colors[@intFromEnum(zgui.StyleCol.button)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY100);
    colors[@intFromEnum(zgui.StyleCol.button_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE200);
    colors[@intFromEnum(zgui.StyleCol.button_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE75);
    colors[@intFromEnum(zgui.StyleCol.header)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE200);
    colors[@intFromEnum(zgui.StyleCol.header_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE100);
    colors[@intFromEnum(zgui.StyleCol.header_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE50);
    colors[@intFromEnum(zgui.StyleCol.separator)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY400);
    colors[@intFromEnum(zgui.StyleCol.separator_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY600);
    colors[@intFromEnum(zgui.StyleCol.separator_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY700);
    colors[@intFromEnum(zgui.StyleCol.resize_grip)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY600);
    colors[@intFromEnum(zgui.StyleCol.resize_grip_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE400);
    colors[@intFromEnum(zgui.StyleCol.resize_grip_active)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE100);
    colors[@intFromEnum(zgui.StyleCol.plot_lines)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE400);
    colors[@intFromEnum(zgui.StyleCol.plot_lines_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE600);
    colors[@intFromEnum(zgui.StyleCol.plot_histogram)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE400);
    colors[@intFromEnum(zgui.StyleCol.plot_histogram_hovered)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE600);
    colors[@intFromEnum(zgui.StyleCol.table_header_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE75);
    colors[@intFromEnum(zgui.StyleCol.table_border_strong)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE600);
    colors[@intFromEnum(zgui.StyleCol.table_border_light)] = zgui.colorConvertU32ToFloat4(LudoStyle.BLUE600);
    colors[@intFromEnum(zgui.StyleCol.table_row_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY100);
    colors[@intFromEnum(zgui.StyleCol.table_row_bg_alt)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY300);
    colors[@intFromEnum(zgui.StyleCol.text_selected_bg)] = zgui.colorConvertU32ToFloat4((LudoStyle.BLUE400 & 0x00FFFFFF) | 0x33000000);
    colors[@intFromEnum(zgui.StyleCol.drag_drop_target)] = .{ 1.00, 1.00, 0.00, 0.90 };
    colors[@intFromEnum(zgui.StyleCol.nav_highlight)] = zgui.colorConvertU32ToFloat4((LudoStyle.GRAY900 & 0x00FFFFFF) | 0x0A000000);
    colors[@intFromEnum(zgui.StyleCol.nav_windowing_highlight)] = .{ 1.00, 1.00, 1.00, 0.70 };
    colors[@intFromEnum(zgui.StyleCol.nav_windowing_dim_bg)] = .{ 0.80, 0.80, 0.80, 0.20 };
    colors[@intFromEnum(zgui.StyleCol.modal_window_dim_bg)] = .{ 0.20, 0.20, 0.20, 0.35 };
    colors[@intFromEnum(zgui.StyleCol.modal_window_dim_bg)] = zgui.colorConvertU32ToFloat4(LudoStyle.GRAY200);
}
