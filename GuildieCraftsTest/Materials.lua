-- Phase 3 scarce materials and Heart of Darkness craft catalogs.
-- Jewelcrafting epic gems remain in Gems.lua.
-- Profession craft lists live in CraftsTailoring.lua (more Crafts*.lua files follow).

GuildieCraftsTest_SCARCE_MATERIALS = {
    heart_of_darkness = {
        id = "heart_of_darkness",
        name = "Heart of Darkness",
        itemId = 32428,
        expansion = "TBC",
        phase = "Phase 3",
        professions = { "tailoring", "leatherworking", "blacksmithing" },
    },
}

GuildieCraftsTest_CraftsByProfession = {
    tailoring = GuildieCraftsTest_TailoringCrafts or {},
    leatherworking = GuildieCraftsTest_LeatherworkingCrafts or {},
    blacksmithing = GuildieCraftsTest_BlacksmithingCrafts or {},
}

GuildieCraftsTest_CraftCategoryOrder = {
    tailoring = GuildieCraftsTest_TailoringCraftCategories,
    leatherworking = GuildieCraftsTest_LeatherworkingCraftCategories,
    blacksmithing = GuildieCraftsTest_BlacksmithingCraftCategories,
}

GuildieCraftsTest_CraftByName = {}
GuildieCraftsTest_CraftByItemId = {}
GuildieCraftsTest_CraftCatalogCache = {}

local function RegisterCraftCatalog()
    GuildieCraftsTest_CraftByName = {}
    GuildieCraftsTest_CraftByItemId = {}
    GuildieCraftsTest_CraftCatalogCache = {}

    for professionId, crafts in pairs(GuildieCraftsTest_CraftsByProfession) do
        for _, craft in ipairs(crafts) do
            craft.profession = craft.profession or professionId
            GuildieCraftsTest_CraftByName[craft.name] = craft
            if craft.itemId then
                GuildieCraftsTest_CraftByItemId[craft.itemId] = craft
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

function GuildieCraftsTest_IsHoDProfession(professionId)
    return HOD_PROFESSIONS[professionId] == true
end

function GuildieCraftsTest_GetScarceMaterial(materialId)
    return GuildieCraftsTest_SCARCE_MATERIALS[materialId]
end

function GuildieCraftsTest_GetScarceMaterialItemId(materialName)
    if not materialName then
        return nil
    end
    for _, material in pairs(GuildieCraftsTest_SCARCE_MATERIALS) do
        if material.name == materialName then
            return material.itemId
        end
    end
    return nil
end

function GuildieCraftsTest_GetScarceMaterialForProfession(professionId)
    if professionId == "jewelcrafting" then
        return nil
    end
    if not GuildieCraftsTest_IsHoDProfession(professionId) then
        return nil
    end
    return GuildieCraftsTest_GetScarceMaterial("heart_of_darkness")
end

function GuildieCraftsTest_GetCraftCatalog(professionId)
    if GuildieCraftsTest_CraftCatalogCache[professionId] then
        return GuildieCraftsTest_CraftCatalogCache[professionId]
    end
    local list = {}
    for _, craft in ipairs(GuildieCraftsTest_CraftsByProfession[professionId] or {}) do
        table.insert(list, craft)
    end
    table.sort(list, function(a, b)
        if a.category ~= b.category then
            return (a.category or "") < (b.category or "")
        end
        return a.name < b.name
    end)
    GuildieCraftsTest_CraftCatalogCache[professionId] = list
    return list
end

function GuildieCraftsTest_GetCraftCategories(professionId)
    local order = GuildieCraftsTest_CraftCategoryOrder[professionId]
    if order then
        local categories = {}
        local seen = {}
        for _, category in ipairs(order) do
            seen[category] = true
            for _, craft in ipairs(GuildieCraftsTest_GetCraftCatalog(professionId)) do
                if craft.category == category then
                    table.insert(categories, category)
                    break
                end
            end
        end
        for _, craft in ipairs(GuildieCraftsTest_GetCraftCatalog(professionId)) do
            local category = craft.category or "Other"
            if not seen[category] then
                table.insert(categories, category)
            end
        end
        return categories
    end

    local seen = {}
    local categories = {}
    for _, craft in ipairs(GuildieCraftsTest_GetCraftCatalog(professionId)) do
        local category = craft.category or "Other"
        if not seen[category] then
            seen[category] = true
            table.insert(categories, category)
        end
    end
    table.sort(categories)
    return categories
end

function GuildieCraftsTest_GetCraftsByCategory(professionId, category)
    local list = {}
    for _, craft in ipairs(GuildieCraftsTest_GetCraftCatalog(professionId)) do
        if craft.category == category then
            table.insert(list, craft)
        end
    end
    return list
end

function GuildieCraftsTest_GetCraftByName(name)
    return GuildieCraftsTest_CraftByName[name]
end

function GuildieCraftsTest_GetCraftByItemId(itemId)
    return GuildieCraftsTest_CraftByItemId[itemId]
end

function GuildieCraftsTest_GetTrackedStockItemIds(professionId)
    local material = GuildieCraftsTest_GetScarceMaterialForProfession(professionId)
    if not material then
        return {}
    end
    return { material.itemId }
end

function GuildieCraftsTest_IsTrackedHoDCraftItemId(itemId)
    local craft = GuildieCraftsTest_CraftByItemId[itemId]
    return craft ~= nil
end

function GuildieCraftsTest_FormatCraftLabel(craft)
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

function GuildieCraftsTest_GetTradeSkillName(professionId)
    return TRADE_SKILL_NAMES[professionId]
end

function GuildieCraftsTest_GetStockCatalog(professionId)
    if professionId == "jewelcrafting" then
        return GuildieCraftsTest_GetRawGems()
    end
    local material = GuildieCraftsTest_GetScarceMaterialForProfession(professionId)
    if material then
        return { { name = material.name, itemId = material.itemId } }
    end
    return {}
end

function GuildieCraftsTest_WorkshopHasRecipeForCraft(craftName)
    if not craftName or craftName == "" then
        return true
    end

    local craft = GuildieCraftsTest_GetCraftByName(craftName)
    if not craft or not craft.itemId then
        return true
    end

    local room = GuildieCraftsTest_GetActiveRoom()
    if not room then
        return true
    end

    GuildieCraftsTestDB = GuildieCraftsTestDB or {}
    GuildieCraftsTestDB.recipes = GuildieCraftsTestDB.recipes or { jcReports = {} }
    local contributors = GuildieCraftsTest_GetWorkshopStockContributors(room)
    if #contributors == 0 then
        return false
    end

    for _, crafterName in ipairs(contributors) do
        local report = GuildieCraftsTestDB.recipes.jcReports[crafterName]
        if report and report.itemIds and report.itemIds[craft.itemId] then
            return true
        end
    end

    return false
end

function GuildieCraftsTest_GetProfessionCraftCount(professionId)
    return #(GuildieCraftsTest_CraftsByProfession[professionId] or {})
end
