-- Workshop metadata: expansion, phase, and profession types.

GuildWorkshop_EXPANSION_PHASES = {
    {
        expansion = "TBC",
        label = "The Burning Crusade",
        phases = { "Phase 3" },
    },
}

GuildWorkshop_PROFESSIONS = {
    { id = "jewelcrafting", label = "Jewelcrafting", enabled = true },
    { id = "tailoring", label = "Tailoring", enabled = true },
    { id = "leatherworking", label = "Leatherworking", enabled = true },
    { id = "blacksmithing", label = "Blacksmithing", enabled = true },
}

local CRAFTER_LABELS = {
    jewelcrafting = "Jewelcrafters",
    tailoring = "Tailors",
    leatherworking = "Leatherworkers",
    blacksmithing = "Blacksmiths",
}

local DEFAULT_EXPANSION = "TBC"
local DEFAULT_PHASE = "Phase 3"

function GuildWorkshop_GetDefaultExpansion()
    return DEFAULT_EXPANSION
end

function GuildWorkshop_GetDefaultPhase()
    return DEFAULT_PHASE
end

function GuildWorkshop_GetExpansionPhaseOptions()
    local options = {}
    for _, entry in ipairs(GuildWorkshop_EXPANSION_PHASES) do
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

function GuildWorkshop_GetProfessionOptions()
    return GuildWorkshop_PROFESSIONS
end

function GuildWorkshop_IsProfessionEnabled(professionId)
    for _, profession in ipairs(GuildWorkshop_PROFESSIONS) do
        if profession.id == professionId then
            return profession.enabled == true
        end
    end
    return false
end

function GuildWorkshop_GetProfessionLabel(professionId)
    for _, profession in ipairs(GuildWorkshop_PROFESSIONS) do
        if profession.id == professionId then
            return profession.label
        end
    end
    return professionId or "Unknown"
end

function GuildWorkshop_GetCrafterLabel(professionId)
    return CRAFTER_LABELS[professionId] or "Crafters"
end

function GuildWorkshop_FormatWorkshopScope(room)
    if not room then
        return ""
    end
    local expansion = room.expansion or DEFAULT_EXPANSION
    local phase = room.phase or DEFAULT_PHASE
    local profession = GuildWorkshop_GetProfessionLabel(room.profession or "jewelcrafting")
    return string.format("%s %s · %s", expansion, phase, profession)
end

function GuildWorkshop_ValidateWorkshopDefinition(name, expansion, phase, profession)
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
    if not GuildWorkshop_IsProfessionEnabled(profession) then
        return false, GuildWorkshop_GetProfessionLabel(profession)
            .. " workshops are not available yet."
    end

    local validExpansion = false
    for _, option in ipairs(GuildWorkshop_GetExpansionPhaseOptions()) do
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

function GuildWorkshop_GetRoomProfession(room)
    if not room then
        return "jewelcrafting"
    end
    return room.profession or "jewelcrafting"
end

function GuildWorkshop_IsJewelcraftingWorkshop(room)
    return GuildWorkshop_GetRoomProfession(room) == "jewelcrafting"
end

function GuildWorkshop_IsWorkshopFullySupported(room)
    return GuildWorkshop_IsProfessionEnabled(GuildWorkshop_GetRoomProfession(room))
end

function GuildWorkshop_GetUnsupportedWorkshopMessage(room)
    local profession = GuildWorkshop_GetProfessionLabel(GuildWorkshop_GetRoomProfession(room))
    if GuildWorkshop_IsProfessionEnabled(GuildWorkshop_GetRoomProfession(room)) then
        return "This workshop is not fully configured yet."
    end
    return profession .. " workshops are not available yet."
end

function GuildWorkshop_GetRoomCrafterSingular(room)
    local labels = {
        jewelcrafting = "Jewelcrafter",
        tailoring = "Tailor",
        leatherworking = "Leatherworker",
        blacksmithing = "Blacksmith",
    }
    return labels[GuildWorkshop_GetRoomProfession(room)] or "Crafter"
end

function GuildWorkshop_GetRoomCrafterShortLabel(room)
    local labels = {
        jewelcrafting = "JC",
        tailoring = "Tailor",
        leatherworking = "LW",
        blacksmithing = "BS",
    }
    return labels[GuildWorkshop_GetRoomProfession(room)] or "Crafter"
end

function GuildWorkshop_GetRoomScarceMaterial(room)
    if not room then
        return nil
    end
    return GuildWorkshop_GetScarceMaterialForProfession(GuildWorkshop_GetRoomProfession(room))
end

function GuildWorkshop_GetRoomScarceMaterialName(room)
    local material = GuildWorkshop_GetRoomScarceMaterial(room)
    return material and material.name or nil
end
