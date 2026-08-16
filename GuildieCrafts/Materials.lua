-- Phase 3 scarce materials and Heart of Darkness craft catalogs.
-- Jewelcrafting epic gems remain in Gems.lua.
-- Profession craft lists live in CraftsTailoring.lua (more Crafts*.lua files follow).

GuildieCrafts_SCARCE_MATERIALS = {
    heart_of_darkness = {
        id = "heart_of_darkness",
        name = "Heart of Darkness",
        itemId = 32428,
        expansion = "TBC",
        phase = "Phase 3",
        professions = { "tailoring", "leatherworking", "blacksmithing" },
    },
}

GuildieCrafts_CraftsByProfession = {
    tailoring = GuildieCrafts_TailoringCrafts or {},
    -- Leatherworking and Blacksmithing HoD catalogs ship in later releases.
    leatherworking = {},
    blacksmithing = {},
}

GuildieCrafts_CraftCategoryOrder = {
    tailoring = GuildieCrafts_TailoringCraftCategories,
}

GuildieCrafts_CraftByName = {}
GuildieCrafts_CraftByItemId = {}
GuildieCrafts_CraftCatalogCache = {}

local function RegisterCraftCatalog()
    GuildieCrafts_CraftByName = {}
    GuildieCrafts_CraftByItemId = {}
    GuildieCrafts_CraftCatalogCache = {}

    for professionId, crafts in pairs(GuildieCrafts_CraftsByProfession) do
        for _, craft in ipairs(crafts) do
            craft.profession = craft.profession or professionId
            GuildieCrafts_CraftByName[craft.name] = craft
            if craft.itemId then
                GuildieCrafts_CraftByItemId[craft.itemId] = craft
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

function GuildieCrafts_IsHoDProfession(professionId)
    return HOD_PROFESSIONS[professionId] == true
end

function GuildieCrafts_GetScarceMaterial(materialId)
    return GuildieCrafts_SCARCE_MATERIALS[materialId]
end

function GuildieCrafts_GetScarceMaterialItemId(materialName)
    if not materialName then
        return nil
    end
    for _, material in pairs(GuildieCrafts_SCARCE_MATERIALS) do
        if material.name == materialName then
            return material.itemId
        end
    end
    return nil
end

function GuildieCrafts_GetScarceMaterialForProfession(professionId)
    if professionId == "jewelcrafting" then
        return nil
    end
    if not GuildieCrafts_IsHoDProfession(professionId) then
        return nil
    end
    return GuildieCrafts_GetScarceMaterial("heart_of_darkness")
end

function GuildieCrafts_GetCraftCatalog(professionId)
    if GuildieCrafts_CraftCatalogCache[professionId] then
        return GuildieCrafts_CraftCatalogCache[professionId]
    end
    local list = {}
    for _, craft in ipairs(GuildieCrafts_CraftsByProfession[professionId] or {}) do
        table.insert(list, craft)
    end
    table.sort(list, function(a, b)
        if a.category ~= b.category then
            return (a.category or "") < (b.category or "")
        end
        return a.name < b.name
    end)
    GuildieCrafts_CraftCatalogCache[professionId] = list
    return list
end

function GuildieCrafts_GetCraftCategories(professionId)
    local order = GuildieCrafts_CraftCategoryOrder[professionId]
    if order then
        local categories = {}
        local seen = {}
        for _, category in ipairs(order) do
            seen[category] = true
            for _, craft in ipairs(GuildieCrafts_GetCraftCatalog(professionId)) do
                if craft.category == category then
                    table.insert(categories, category)
                    break
                end
            end
        end
        for _, craft in ipairs(GuildieCrafts_GetCraftCatalog(professionId)) do
            local category = craft.category or "Other"
            if not seen[category] then
                table.insert(categories, category)
            end
        end
        return categories
    end

    local seen = {}
    local categories = {}
    for _, craft in ipairs(GuildieCrafts_GetCraftCatalog(professionId)) do
        local category = craft.category or "Other"
        if not seen[category] then
            seen[category] = true
            table.insert(categories, category)
        end
    end
    table.sort(categories)
    return categories
end

function GuildieCrafts_GetCraftsByCategory(professionId, category)
    local list = {}
    for _, craft in ipairs(GuildieCrafts_GetCraftCatalog(professionId)) do
        if craft.category == category then
            table.insert(list, craft)
        end
    end
    return list
end

function GuildieCrafts_GetCraftByName(name)
    return GuildieCrafts_CraftByName[name]
end

function GuildieCrafts_GetCraftByItemId(itemId)
    return GuildieCrafts_CraftByItemId[itemId]
end

function GuildieCrafts_GetTrackedStockItemIds(professionId)
    local material = GuildieCrafts_GetScarceMaterialForProfession(professionId)
    if not material then
        return {}
    end
    return { material.itemId }
end

function GuildieCrafts_IsTrackedHoDCraftItemId(itemId)
    local craft = GuildieCrafts_CraftByItemId[itemId]
    return craft ~= nil
end

function GuildieCrafts_FormatCraftLabel(craft)
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

function GuildieCrafts_GetTradeSkillName(professionId)
    return TRADE_SKILL_NAMES[professionId]
end

function GuildieCrafts_GetStockCatalog(professionId)
    if professionId == "jewelcrafting" then
        return GuildieCrafts_GetRawGems()
    end
    local material = GuildieCrafts_GetScarceMaterialForProfession(professionId)
    if material then
        return { { name = material.name, itemId = material.itemId } }
    end
    return {}
end

function GuildieCrafts_WorkshopHasRecipeForCraft(craftName)
    if not craftName or craftName == "" then
        return true
    end

    local craft = GuildieCrafts_GetCraftByName(craftName)
    if not craft or not craft.itemId then
        return true
    end

    local room = GuildieCrafts_GetActiveRoom()
    if not room then
        return true
    end

    GuildieCraftsDB = GuildieCraftsDB or {}
    GuildieCraftsDB.recipes = GuildieCraftsDB.recipes or { jcReports = {} }
    local contributors = GuildieCrafts_GetWorkshopStockContributors(room)
    if #contributors == 0 then
        return false
    end

    for _, crafterName in ipairs(contributors) do
        local report = GuildieCraftsDB.recipes.jcReports[crafterName]
        if report and report.itemIds and report.itemIds[craft.itemId] then
            return true
        end
    end

    return false
end

function GuildieCrafts_GetProfessionCraftCount(professionId)
    return #(GuildieCrafts_CraftsByProfession[professionId] or {})
end
