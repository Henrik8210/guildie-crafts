-- Phase 3 scarce materials and Heart of Darkness craft catalogs.
-- Jewelcrafting epic gems remain in Gems.lua.
-- Profession craft lists live in CraftsTailoring.lua (more Crafts*.lua files follow).

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

GuildWorkshopTest_CraftsByProfession = {
    tailoring = GuildWorkshopTest_TailoringCrafts or {},
    -- Leatherworking and Blacksmithing HoD catalogs ship in later releases.
    leatherworking = {},
    blacksmithing = {},
}

GuildWorkshopTest_CraftCategoryOrder = {
    tailoring = GuildWorkshopTest_TailoringCraftCategories,
}

GuildWorkshopTest_CraftByName = {}
GuildWorkshopTest_CraftByItemId = {}
GuildWorkshopTest_CraftCatalogCache = {}

local function RegisterCraftCatalog()
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
end

RegisterCraftCatalog()

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
    local order = GuildWorkshopTest_CraftCategoryOrder[professionId]
    if order then
        local categories = {}
        local seen = {}
        for _, category in ipairs(order) do
            seen[category] = true
            for _, craft in ipairs(GuildWorkshopTest_GetCraftCatalog(professionId)) do
                if craft.category == category then
                    table.insert(categories, category)
                    break
                end
            end
        end
        for _, craft in ipairs(GuildWorkshopTest_GetCraftCatalog(professionId)) do
            local category = craft.category or "Other"
            if not seen[category] then
                table.insert(categories, category)
            end
        end
        return categories
    end

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
    local parts = {}
    if craft.slot then
        table.insert(parts, craft.slot)
    end
    if craft.hodCost then
        table.insert(parts, craft.hodCost .. " HoD")
    end
    if #parts > 0 then
        return string.format("%s (%s)", craft.name, table.concat(parts, " · "))
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

function GuildWorkshopTest_GetProfessionCraftCount(professionId)
    return #(GuildWorkshopTest_CraftsByProfession[professionId] or {})
end
