-- TBC Phase 3 Tailoring crafts that consume Heart of Darkness.
-- Patterns from Black Temple (Okuno / drops). Item IDs: wowhead.com/tbc/item=
-- HoD costs from recipe reagents (Anniversary Phase 3).

GuildieCraftsTest_TailoringCrafts = {
    -- Shadow resistance (Mother Shahraz) — Night's End is the guild priority craft
    {
        name = "Night's End",
        itemId = 32420,
        hodCost = 1,
        category = "Shadow Resist",
        slot = "Back",
        class = "All",
        bind = "BoE",
        notes = "40 shadow resistance — craft for every raider",
    },
    {
        name = "Soulguard Bracers",
        itemId = 32392,
        hodCost = 1,
        category = "Shadow Resist",
        slot = "Wrist",
        class = "Cloth",
        bind = "BoE",
        set = "Soulguard",
    },
    {
        name = "Soulguard Girdle",
        itemId = 32390,
        hodCost = 2,
        category = "Shadow Resist",
        slot = "Waist",
        class = "Cloth",
        bind = "BoE",
        set = "Soulguard",
    },
    {
        name = "Soulguard Leggings",
        itemId = 32389,
        hodCost = 3,
        category = "Shadow Resist",
        slot = "Legs",
        class = "Cloth",
        bind = "BoE",
        set = "Soulguard",
    },
    {
        name = "Soulguard Slippers",
        itemId = 32391,
        hodCost = 2,
        category = "Shadow Resist",
        slot = "Feet",
        class = "Cloth",
        bind = "BoE",
        set = "Soulguard",
    },

    -- Healer (Swiftheal — Mooncloth / Primal Life)
    {
        name = "Swiftheal Wraps",
        itemId = 32584,
        hodCost = 4,
        category = "Healer",
        slot = "Wrist",
        class = "Cloth",
        bind = "BoE",
        set = "Swiftheal",
        notes = "Strong Phase 3 healer bracers",
    },
    {
        name = "Swiftheal Mantle",
        itemId = 32585,
        hodCost = 2,
        category = "Healer",
        slot = "Shoulder",
        class = "Cloth",
        bind = "BoP",
        set = "Swiftheal",
    },

    -- Caster DPS (Nimble Thought — Spellcloth / haste)
    {
        name = "Bracers of Nimble Thought",
        itemId = 32586,
        hodCost = 4,
        category = "Caster",
        slot = "Wrist",
        class = "Cloth",
        bind = "BoE",
        set = "Nimble Thought",
        notes = "Spell haste — BiS bracers for many casters",
    },
    {
        name = "Mantle of Nimble Thought",
        itemId = 32587,
        hodCost = 2,
        category = "Caster",
        slot = "Shoulder",
        class = "Cloth",
        bind = "BoP",
        set = "Nimble Thought",
    },
}

GuildieCraftsTest_TailoringCraftCategories = { "Shadow Resist", "Healer", "Caster" }
