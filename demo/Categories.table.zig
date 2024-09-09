//
// AUTO GENERATATED BY Ludo DB
//

pub const LudoString = []u8;

pub const Categories__parents = struct {
    pub const name = "Categories__parents";
    pub const row_count = 8;
    pub const max_fk_count = 7;

    Parent: u64 = undefined,
};

pub const Categories = struct {
    pub const name = "Categories";
    pub const row_count = 5;

    category: [row_count]LudoString = undefined,
    parent: [row_count]u64 = undefined,
    parents: [row_count][7]Categories__parents = undefined,
};

pub fn create_Categories() Categories {
    const table : Categories = .{
        .parent = .{
            empty3
            empty3
            empty4
            empty5dfdfddd
        },

        .parents = .{
            TABLE
            TABLE
            TABLE
            TABLE
        },

    };

    return table;
}

