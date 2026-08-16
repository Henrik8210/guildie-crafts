-- Phase 3 scarce materials and Heart of Darkness crafts (Tailoring / LW / BS).
-- Jewelcrafting epic gems remain in Gems.lua.
-- Item IDs verified at wowhead.com/tbc/item=...
-- v1.1: wire Stock.lua, Recipes.lua, and the order modal to these catalogs.

GuildWorkshopTest_SCARCE_MATERIALS = {
    heart_of_darkness = {
        id = "heart_of_darkness",
        name = "Heart of Darkness",
        itemId = 32428,
        expansion = "TBC",
        phase = "Phase 3",
        professions = { "tailoring", "leatherworking", "blacksmithing" },
    },
}

-- HoD output crafts keyed by profession. Each entry is one order/recipe row.
-- hodCost = Hearts consumed per craft (most recipes use 1).
GuildWorkshopTest_CraftsByProfession = {
    tailoring = {
        { name = "Night's End", itemId = 32590, hodCost = 1, category = "Shadow Resist", slot = "Back", class = "All", notes = "Universal shadow-res cloak" },
        { name = "Bracers of Nimble Thought", itemId = 32586, hodCost = 1, category = "Caster", slot = "Wrist", class = "Cloth" },
        { name = "Mantle of Nimble Thought", itemId = 32587, hodCost = 1, category = "Caster", slot = "Shoulder", class = "Cloth" },
        { name = "Swiftheal Wraps", itemId = 32582, hodCost = 1, category = "Healer", slot = "Wrist", class = "Cloth" },
        { name = "Swiftheal Mantle", itemId = 32583, hodCost = 1, category = "Healer", slot = "Shoulder", class = "Cloth" },
        { name = "Soulguard Bracers", itemId = 32389, hodCost = 1, category = "Shadow Resist", slot = "Wrist", class = "Cloth" },
        { name = "Soulguard Girdle", itemId = 32390, hodCost = 1, category = "Shadow Resist", slot = "Waist", class = "Cloth" },
        { name = "Soulguard Leggings", itemId = 32391, hodCost = 1, category = "Shadow Resist", slot = "Legs", class = "Cloth" },
        { name = "Soulguard Slippers", itemId = 32392, hodCost = 1, category = "Shadow Resist", slot = "Feet", class = "Cloth" },
    },
    leatherworking = {
        { name = "Bindings of Lightning Reflexes", itemId = 32574, hodCost = 1, category = "Physical DPS", slot = "Wrist", class = "Mail" },
        { name = "Shoulders of Lightning Reflexes", itemId = 32575, hodCost = 1, category = "Physical DPS", slot = "Shoulder", class = "Mail" },
        { name = "Living Earth Bindings", itemId = 32579, hodCost = 1, category = "Healer", slot = "Wrist", class = "Mail" },
        { name = "Living Earth Shoulders", itemId = 32580, hodCost = 1, category = "Healer", slot = "Shoulder", class = "Mail" },
        { name = "Swiftstrike Shoulders", itemId = 32578, hodCost = 1, category = "Physical DPS", slot = "Shoulder", class = "Leather" },
        { name = "Waistguard of Shackled Souls", itemId = 32393, hodCost = 1, category = "Shadow Resist", slot = "Waist", class = "Mail" },
        { name = "Boots of Shackled Souls", itemId = 32366, hodCost = 1, category = "Shadow Resist", slot = "Feet", class = "Mail" },
        { name = "Greaves of Shackled Souls", itemId = 32367, hodCost = 1, category = "Shadow Resist", slot = "Legs", class = "Mail" },
        { name = "Redeemed Soul Moccasins", itemId = 32395, hodCost = 1, category = "Shadow Resist", slot = "Feet", class = "Leather" },
        { name = "Redeemed Soul Wristguards", itemId = 32396, hodCost = 1, category = "Shadow Resist", slot = "Wrist", class = "Leather" },
        { name = "Redeemed Soul Legguards", itemId = 32397, hodCost = 1, category = "Shadow Resist", slot = "Legs", class = "Leather" },
        { name = "Redeemed Soul Cinch", itemId = 32394, hodCost = 1, category = "Shadow Resist", slot = "Waist", class = "Leather" },
    },
    blacksmithing = {
        { name = "Dawnsteel Bracers", itemId = 32568, hodCost = 1, category = "Physical DPS", slot = "Wrist", class = "Plate" },
        { name = "Dawnsteel Shoulders", itemId = 32569, hodCost = 1, category = "Physical DPS", slot = "Shoulder", class = "Plate" },
        { name = "Swiftsteel Bracers", itemId = 32572, hodCost = 1, category = "Physical DPS", slot = "Wrist", class = "Plate" },
        { name = "Swiftsteel Shoulders", itemId = 32573, hodCost = 1, category = "Physical DPS", slot = "Shoulder", class = "Plate" },
        { name = "Shadesteel Bracers", itemId = 32570, hodCost = 1, category = "Shadow Resist", slot = "Wrist", class = "Plate" },
        { name = "Shadesteel Greaves", itemId = 32571, hodCost = 1, category = "Shadow Resist", slot = "Legs", class = "Plate" },
    },
}

GuildWorkshopTest_CraftByName = {}
GuildWorkshopTest_CraftByItemId = {}
GuildWorkshopTest_CraftCatalogCache = {}

for professionId, crafts in pairs(GuildWorkshopTest_CraftsByProfession) do
    for _, craft in ipairs(crafts) do
        craft.profession = craft.profession or professionId
        GuildWorkshopTest_CraftByName[craft.name] = craft
        if craft.itemId then
            GuildWorkshopTest_CraftByItemId[craft.itemId] = craft
        end
    end
end

local HOD_PROFESSIONS = {
    tailoring = true,
    leatherworking = true,
    blacksmithing = true,
}

function GuildWorkshopTest_IsHoDProfession(professionId)
    return HOD_PROFESSIONS[professionId] == true
end

function GuildWorkshopTest_GetScarceMaterial(materialId)
    return GuildWorkshopTest_SCARCE_MATERIALS[materialId]
end

function GuildWorkshopTest_GetScarceMaterialForProfession(professionId)
    if professionId == "jewelcrafting" then
        return nil
    end
    if not GuildWorkshopTest_IsHoDProfession(professionId) then
        return nil
    end
    return GuildWorkshopTest_GetScarceMaterial("heart_of_darkness")
end

function GuildWorkshopTest_GetCraftCatalog(professionId)
    if GuildWorkshopTest_CraftCatalogCache[professionId] then
        return GuildWorkshopTest_CraftCatalogCache[professionId]
    end
    local list = {}
    for _, craft in ipairs(GuildWorkshopTest_CraftsByProfession[professionId] or {}) do
        table.insert(list, craft)
    end
    table.sort(list, function(a, b)
        if a.category ~= b.category then
            return (a.category or "") < (b.category or "")
        end
        return a.name < b.name
    end)
    GuildWorkshopTest_CraftCatalogCache[professionId] = list
    return list
end

function GuildWorkshopTest_GetCraftCategories(professionId)
    local seen = {}
    local categories = {}
    for _, craft in ipairs(GuildWorkshopTest_GetCraftCatalog(professionId)) do
        local category = craft.category or "Other"
        if not seen[category] then
            seen[category] = true
            table.insert(categories, category)
        end
    end
    table.sort(categories)
    return categories
end

function GuildWorkshopTest_GetCraftsByCategory(professionId, category)
    local list = {}
    for _, craft in ipairs(GuildWorkshopTest_GetCraftCatalog(professionId)) do
        if craft.category == category then
            table.insert(list, craft)
        end
    end
    return list
end

function GuildWorkshopTest_GetCraftByName(name)
    return GuildWorkshopTest_CraftByName[name]
end

function GuildWorkshopTest_GetCraftByItemId(itemId)
    return GuildWorkshopTest_CraftByItemId[itemId]
end

function GuildWorkshopTest_GetTrackedStockItemIds(professionId)
    local material = GuildWorkshopTest_GetScarceMaterialForProfession(professionId)
    if not material then
        return {}
    end
    return { material.itemId }
end

function GuildWorkshopTest_IsTrackedHoDCraftItemId(itemId)
    local craft = GuildWorkshopTest_CraftByItemId[itemId]
    return craft ~= nil
end

function GuildWorkshopTest_FormatCraftLabel(craft)
    if not craft then
        return ""
    end
    if craft.slot and craft.category then
        return string.format("%s (%s · %s)", craft.name, craft.slot, craft.category)
    end
    return craft.name
end

local TRADE_SKILL_NAMES = {
    tailoring = "Tailoring",
    leatherworking = "Leatherworking",
    blacksmithing = "Blacksmithing",
}

function GuildWorkshopTest_GetTradeSkillName(professionId)
    return TRADE_SKILL_NAMES[professionId]
end

function GuildWorkshopTest_GetStockCatalog(professionId)
    if professionId == "jewelcrafting" then
        return GuildWorkshopTest_GetRawGems()
    end
    local material = GuildWorkshopTest_GetScarceMaterialForProfession(professionId)
    if material then
        return { { name = material.name, itemId = material.itemId } }
    end
    return {}
end

function GuildWorkshopTest_WorkshopHasRecipeForCraft(craftName)
    if not craftName or craftName == "" then
        return true
    end

    local craft = GuildWorkshopTest_GetCraftByName(craftName)
    if not craft or not craft.itemId then
        return true
    end

    local room = GuildWorkshopTest_GetActiveRoom()
    if not room then
        return true
    end

    GuildWorkshopTestDB = GuildWorkshopTestDB or {}
    GuildWorkshopTestDB.recipes = GuildWorkshopTestDB.recipes or { jcReports = {} }
    local contributors = GuildWorkshopTest_GetWorkshopStockContributors(room)
    if #contributors == 0 then
        return false
    end

    for _, crafterName in ipairs(contributors) do
        local report = GuildWorkshopTestDB.recipes.jcReports[crafterName]
        if report and report.itemIds and report.itemIds[craft.itemId] then
            return true
        end
    end

    return false
end
