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
    integer_col: [row_count]i64 = undefined,
};

pub fn create_Categories() Categories {
    const table : Categories = .{
        .parent = .{
            // Reference to Categories::category
            1, // empty3
            1, // empty3
            2, // empty4
            3, // empty5dfdfddd
        .parents = .{
         .{1,LOL         },
4,LOL         },
2,LOL         },
         },
1,LOL         },
1,LOL         },
4,LOL         },
         .{         },
         },
         },
         },
         },
         },
         },
         .{         },
         },
         },
4,LOL         },
         },
         },
         },
         .{         },
         },
         },
         },
         },
         },
         },
        .integer_col = .{
            0,
            27,
            0,
            0,
        },

    };

    return table;
}

