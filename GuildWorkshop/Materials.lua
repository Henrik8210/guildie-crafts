-- Phase 3 scarce materials and Heart of Darkness craft catalogs.
-- Jewelcrafting epic gems remain in Gems.lua.
-- Profession craft lists live in CraftsTailoring.lua (more Crafts*.lua files follow).

GuildWorkshop_SCARCE_MATERIALS = {
    heart_of_darkness = {
        id = "heart_of_darkness",
        name = "Heart of Darkness",
        itemId = 32428,
        expansion = "TBC",
        phase = "Phase 3",
        professions = { "tailoring", "leatherworking", "blacksmithing" },
    },
}

GuildWorkshop_CraftsByProfession = {
    tailoring = GuildWorkshop_TailoringCrafts or {},
    -- Leatherworking and Blacksmithing HoD catalogs ship in later releases.
    leatherworking = {},
    blacksmithing = {},
}

GuildWorkshop_CraftCategoryOrder = {
    tailoring = GuildWorkshop_TailoringCraftCategories,
}

GuildWorkshop_CraftByName = {}
GuildWorkshop_CraftByItemId = {}
GuildWorkshop_CraftCatalogCache = {}

local function RegisterCraftCatalog()
    GuildWorkshop_CraftByName = {}
    GuildWorkshop_CraftByItemId = {}
    GuildWorkshop_CraftCatalogCache = {}

    for professionId, crafts in pairs(GuildWorkshop_CraftsByProfession) do
        for _, craft in ipairs(crafts) do
            craft.profession = craft.profession or professionId
            GuildWorkshop_CraftByName[craft.name] = craft
            if craft.itemId then
                GuildWorkshop_CraftByItemId[craft.itemId] = craft
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

function GuildWorkshop_IsHoDProfession(professionId)
    return HOD_PROFESSIONS[professionId] == true
end

function GuildWorkshop_GetScarceMaterial(materialId)
    return GuildWorkshop_SCARCE_MATERIALS[materialId]
end

function GuildWorkshop_GetScarceMaterialForProfession(professionId)
    if professionId == "jewelcrafting" then
        return nil
    end
    if not GuildWorkshop_IsHoDProfession(professionId) then
        return nil
    end
    return GuildWorkshop_GetScarceMaterial("heart_of_darkness")
end

function GuildWorkshop_GetCraftCatalog(professionId)
    if GuildWorkshop_CraftCatalogCache[professionId] then
        return GuildWorkshop_CraftCatalogCache[professionId]
    end
    local list = {}
    for _, craft in ipairs(GuildWorkshop_CraftsByProfession[professionId] or {}) do
        table.insert(list, craft)
    end
    table.sort(list, function(a, b)
        if a.category ~= b.category then
            return (a.category or "") < (b.category or "")
        end
        return a.name < b.name
    end)
    GuildWorkshop_CraftCatalogCache[professionId] = list
    return list
end

function GuildWorkshop_GetCraftCategories(professionId)
    local order = GuildWorkshop_CraftCategoryOrder[professionId]
    if order then
        local categories = {}
        local seen = {}
        for _, category in ipairs(order) do
            seen[category] = true
            for _, craft in ipairs(GuildWorkshop_GetCraftCatalog(professionId)) do
                if craft.category == category then
                    table.insert(categories, category)
                    break
                end
            end
        end
        for _, craft in ipairs(GuildWorkshop_GetCraftCatalog(professionId)) do
            local category = craft.category or "Other"
            if not seen[category] then
                table.insert(categories, category)
            end
        end
        return categories
    end

    local seen = {}
    local categories = {}
    for _, craft in ipairs(GuildWorkshop_GetCraftCatalog(professionId)) do
        local category = craft.category or "Other"
        if not seen[category] then
            seen[category] = true
            table.insert(categories, category)
        end
    end
    table.sort(categories)
    return categories
end

function GuildWorkshop_GetCraftsByCategory(professionId, category)
    local list = {}
    for _, craft in ipairs(GuildWorkshop_GetCraftCatalog(professionId)) do
        if craft.category == category then
            table.insert(list, craft)
        end
    end
    return list
end

function GuildWorkshop_GetCraftByName(name)
    return GuildWorkshop_CraftByName[name]
end

function GuildWorkshop_GetCraftByItemId(itemId)
    return GuildWorkshop_CraftByItemId[itemId]
end

function GuildWorkshop_GetTrackedStockItemIds(professionId)
    local material = GuildWorkshop_GetScarceMaterialForProfession(professionId)
    if not material then
        return {}
    end
    return { material.itemId }
end

function GuildWorkshop_IsTrackedHoDCraftItemId(itemId)
    local craft = GuildWorkshop_CraftByItemId[itemId]
    return craft ~= nil
end

function GuildWorkshop_FormatCraftLabel(craft)
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

function GuildWorkshop_GetTradeSkillName(professionId)
    return TRADE_SKILL_NAMES[professionId]
end

function GuildWorkshop_GetStockCatalog(professionId)
    if professionId == "jewelcrafting" then
        return GuildWorkshop_GetRawGems()
    end
    local material = GuildWorkshop_GetScarceMaterialForProfession(professionId)
    if material then
        return { { name = material.name, itemId = material.itemId } }
    end
    return {}
end

function GuildWorkshop_WorkshopHasRecipeForCraft(craftName)
    if not craftName or craftName == "" then
        return true
    end

    local craft = GuildWorkshop_GetCraftByName(craftName)
    if not craft or not craft.itemId then
        return true
    end

    local room = GuildWorkshop_GetActiveRoom()
    if not room then
        return true
    end

    GuildWorkshopDB = GuildWorkshopDB or {}
    GuildWorkshopDB.recipes = GuildWorkshopDB.recipes or { jcReports = {} }
    local contributors = GuildWorkshop_GetWorkshopStockContributors(room)
    if #contributors == 0 then
        return false
    end

    for _, crafterName in ipairs(contributors) do
        local report = GuildWorkshopDB.recipes.jcReports[crafterName]
        if report and report.itemIds and report.itemIds[craft.itemId] then
            return true
        end
    end

    return false
end

function GuildWorkshop_GetProfessionCraftCount(professionId)
    return #(GuildWorkshop_CraftsByProfession[professionId] or {})
end
