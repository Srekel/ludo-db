//
// AUTO GENERATATED BY Ludo DB
//

pub const LudoString = []u8;

pub const Categories = struct {
    pub const name = "Categories";
    pub const row_count = 5;

    PK: [row_count]i64 = undefined,
    category: [row_count]LudoString = undefined,
    parent: [row_count]u64 = undefined,
    parents: [row_count]unknown = undefined,
};
