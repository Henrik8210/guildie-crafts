-- Workshop metadata: expansion, phase, and profession types.

GuildWorkshopTest_EXPANSION_PHASES = {
    {
        expansion = "TBC",
        label = "The Burning Crusade",
        phases = { "Phase 3" },
    },
}

GuildWorkshopTest_PROFESSIONS = {
    { id = "jewelcrafting", label = "Jewelcrafting", enabled = true },
    { id = "tailoring", label = "Tailoring", enabled = true },
    { id = "leatherworking", label = "Leatherworking", enabled = false },
    { id = "blacksmithing", label = "Blacksmithing", enabled = false },
}

local CRAFTER_LABELS = {
    jewelcrafting = "Jewelcrafters",
    tailoring = "Tailors",
    leatherworking = "Leatherworkers",
    blacksmithing = "Blacksmiths",
}

local DEFAULT_EXPANSION = "TBC"
local DEFAULT_PHASE = "Phase 3"

function GuildWorkshopTest_GetDefaultExpansion()
    return DEFAULT_EXPANSION
end

function GuildWorkshopTest_GetDefaultPhase()
    return DEFAULT_PHASE
end

function GuildWorkshopTest_GetExpansionPhaseOptions()
    local options = {}
    for _, entry in ipairs(GuildWorkshopTest_EXPANSION_PHASES) do
        for _, phase in ipairs(entry.phases) do
            table.insert(options, {
                expansion = entry.expansion,
                phase = phase,
                label = entry.label .. " — " .. phase,
            })
        end
    end
    return options
end

function GuildWorkshopTest_GetProfessionOptions()
    return GuildWorkshopTest_PROFESSIONS
end

function GuildWorkshopTest_IsProfessionEnabled(professionId)
    for _, profession in ipairs(GuildWorkshopTest_PROFESSIONS) do
        if profession.id == professionId then
            return profession.enabled == true
        end
    end
    return false
end

function GuildWorkshopTest_GetProfessionLabel(professionId)
    for _, profession in ipairs(GuildWorkshopTest_PROFESSIONS) do
        if profession.id == professionId then
            return profession.label
        end
    end
    return professionId or "Unknown"
end

function GuildWorkshopTest_GetCrafterLabel(professionId)
    return CRAFTER_LABELS[professionId] or "Crafters"
end

function GuildWorkshopTest_FormatWorkshopScope(room)
    if not room then
        return ""
    end
    local expansion = room.expansion or DEFAULT_EXPANSION
    local phase = room.phase or DEFAULT_PHASE
    local profession = GuildWorkshopTest_GetProfessionLabel(room.profession or "jewelcrafting")
    return string.format("%s %s · %s", expansion, phase, profession)
end

function GuildWorkshopTest_ValidateWorkshopDefinition(name, expansion, phase, profession)
    name = strtrim(name or "")
    if name == "" then
        return false, "Enter a workshop name."
    end
    if not expansion or not phase then
        return false, "Select an expansion and phase."
    end
    if not profession then
        return false, "Select a profession."
    end
    if not GuildWorkshopTest_IsProfessionEnabled(profession) then
        return false, GuildWorkshopTest_GetProfessionLabel(profession)
            .. " workshops are coming in a future release."
    end

    local validExpansion = false
    for _, option in ipairs(GuildWorkshopTest_GetExpansionPhaseOptions()) do
        if option.expansion == expansion and option.phase == phase then
            validExpansion = true
            break
        end
    end
    if not validExpansion then
        return false, "Select a valid expansion and phase."
    end

    return true
end

function GuildWorkshopTest_GetRoomProfession(room)
    if not room then
        return "jewelcrafting"
    end
    return room.profession or "jewelcrafting"
end

function GuildWorkshopTest_IsJewelcraftingWorkshop(room)
    return GuildWorkshopTest_GetRoomProfession(room) == "jewelcrafting"
end

function GuildWorkshopTest_IsWorkshopFullySupported(room)
    return GuildWorkshopTest_IsProfessionEnabled(GuildWorkshopTest_GetRoomProfession(room))
end

function GuildWorkshopTest_GetUnsupportedWorkshopMessage(room)
    local profession = GuildWorkshopTest_GetProfessionLabel(GuildWorkshopTest_GetRoomProfession(room))
    if GuildWorkshopTest_IsProfessionEnabled(GuildWorkshopTest_GetRoomProfession(room)) then
        return "This workshop is not fully configured yet."
    end
    return profession .. " workshops are not available yet."
end

function GuildWorkshopTest_GetRoomCrafterSingular(room)
    local labels = {
        jewelcrafting = "Jewelcrafter",
        tailoring = "Tailor",
        leatherworking = "Leatherworker",
        blacksmithing = "Blacksmith",
    }
    return labels[GuildWorkshopTest_GetRoomProfession(room)] or "Crafter"
end

function GuildWorkshopTest_GetRoomCrafterShortLabel(room)
    local labels = {
        jewelcrafting = "JC",
        tailoring = "Tailor",
        leatherworking = "LW",
        blacksmithing = "BS",
    }
    return labels[GuildWorkshopTest_GetRoomProfession(room)] or "Crafter"
end

function GuildWorkshopTest_GetRoomScarceMaterial(room)
    if not room then
        return nil
    end
    return GuildWorkshopTest_GetScarceMaterialForProfession(GuildWorkshopTest_GetRoomProfession(room))
end

function GuildWorkshopTest_GetRoomScarceMaterialName(room)
    local material = GuildWorkshopTest_GetRoomScarceMaterial(room)
    return material and material.name or nil
end
