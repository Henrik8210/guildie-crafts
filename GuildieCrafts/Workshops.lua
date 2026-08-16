-- Workshop metadata: expansion, phase, and profession types.

local ADDON_NAME = ...

GuildieCrafts_EXPANSION_PHASES = {
    {
        expansion = "TBC",
        label = "TBC",
        enabled = true,
        phases = { "Phase 3" },
    },
    {
        expansion = "WOTLK",
        label = "WOTLK",
        enabled = false,
        phases = {},
    },
}

GuildieCrafts_PROFESSIONS = {
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

-- Trade-skill icon fallbacks (same filenames as the profession spell icons).
local PROFESSION_SPELL_IDS = {
    jewelcrafting = 28897,
    tailoring = 26790,
    leatherworking = 26798,
    blacksmithing = 29844,
}

local PROFESSION_ICONS = {
    jewelcrafting = "Interface\\Icons\\Trade_JewelCrafting",
    tailoring = "Interface\\Icons\\Trade_Tailoring",
    leatherworking = "Interface\\Icons\\Trade_LeatherWorking",
    blacksmithing = "Interface\\Icons\\Trade_BlackSmithing",
}

local DEFAULT_WORKSHOP_ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Art\\WorkshopLogo"
local DEFAULT_WORKSHOP_PORTRAIT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Art\\WorkshopLogoPortrait"

local function ResolveSpellIcon(spellId)
    if not spellId then
        return nil
    end
    if GetSpellTexture then
        local texture = GetSpellTexture(spellId)
        if texture then
            return texture
        end
    end
    if GetSpellInfo then
        local _, _, icon = GetSpellInfo(spellId)
        if icon then
            return icon
        end
    end
    return nil
end

local DEFAULT_EXPANSION = "TBC"
local DEFAULT_PHASE = "Phase 3"

function GuildieCrafts_GetDefaultExpansion()
    return DEFAULT_EXPANSION
end

function GuildieCrafts_GetDefaultPhase()
    return DEFAULT_PHASE
end

function GuildieCrafts_GetExpansionPhaseOptions()
    local options = {}
    for _, entry in ipairs(GuildieCrafts_EXPANSION_PHASES) do
        for _, phase in ipairs(entry.phases or {}) do
            table.insert(options, {
                expansion = entry.expansion,
                phase = phase,
                label = entry.label .. " — " .. phase,
            })
        end
    end
    return options
end

function GuildieCrafts_GetExpansionOptions()
    local options = {}
    for _, entry in ipairs(GuildieCrafts_EXPANSION_PHASES) do
        table.insert(options, {
            expansion = entry.expansion,
            label = entry.label,
            enabled = entry.enabled ~= false,
        })
    end
    return options
end

function GuildieCrafts_GetPhaseOptions(expansionId)
    local phases = {}
    for _, entry in ipairs(GuildieCrafts_EXPANSION_PHASES) do
        if entry.expansion == expansionId then
            for _, phase in ipairs(entry.phases or {}) do
                table.insert(phases, {
                    phase = phase,
                    label = phase,
                })
            end
            break
        end
    end
    return phases
end

function GuildieCrafts_IsExpansionEnabled(expansionId)
    for _, entry in ipairs(GuildieCrafts_EXPANSION_PHASES) do
        if entry.expansion == expansionId then
            return entry.enabled ~= false
        end
    end
    return false
end

function GuildieCrafts_GetProfessionOptions()
    return GuildieCrafts_PROFESSIONS
end

function GuildieCrafts_IsProfessionEnabled(professionId)
    for _, profession in ipairs(GuildieCrafts_PROFESSIONS) do
        if profession.id == professionId then
            return profession.enabled == true
        end
    end
    return false
end

function GuildieCrafts_GetProfessionLabel(professionId)
    for _, profession in ipairs(GuildieCrafts_PROFESSIONS) do
        if profession.id == professionId then
            return profession.label
        end
    end
    return professionId or "Unknown"
end

function GuildieCrafts_GetCrafterLabel(professionId)
    return CRAFTER_LABELS[professionId] or "Crafters"
end

function GuildieCrafts_GetProfessionIcon(professionId)
    local spellId = PROFESSION_SPELL_IDS[professionId]
    local resolved = ResolveSpellIcon(spellId)
    if resolved then
        return resolved
    end
    return PROFESSION_ICONS[professionId] or DEFAULT_WORKSHOP_ICON
end

function GuildieCrafts_GetDefaultWorkshopIcon()
    return DEFAULT_WORKSHOP_ICON
end

function GuildieCrafts_GetDefaultWorkshopPortrait()
    return DEFAULT_WORKSHOP_PORTRAIT
end

function GuildieCrafts_GetWorkshopPortraitIcon(room)
    if not room then
        return DEFAULT_WORKSHOP_PORTRAIT
    end
    return GuildieCrafts_GetProfessionIcon(GuildieCrafts_GetRoomProfession(room))
end

function GuildieCrafts_FormatWorkshopScope(room)
    if not room then
        return ""
    end
    local expansion = room.expansion or DEFAULT_EXPANSION
    local phase = room.phase or DEFAULT_PHASE
    local profession = GuildieCrafts_GetProfessionLabel(room.profession or "jewelcrafting")
    return string.format("%s %s · %s", expansion, phase, profession)
end

function GuildieCrafts_ValidateWorkshopDefinition(name, expansion, phase, profession)
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
    if not GuildieCrafts_IsProfessionEnabled(profession) then
        return false, GuildieCrafts_GetProfessionLabel(profession)
            .. " workshops are coming in a future release."
    end
    if not GuildieCrafts_IsExpansionEnabled(expansion) then
        return false, "That expansion is not available yet."
    end

    local validPhase = false
    for _, option in ipairs(GuildieCrafts_GetPhaseOptions(expansion)) do
        if option.phase == phase then
            validPhase = true
            break
        end
    end
    if not validPhase then
        return false, "Select a valid phase."
    end

    return true
end

function GuildieCrafts_GetRoomProfession(room)
    if not room then
        return "jewelcrafting"
    end
    return room.profession or "jewelcrafting"
end

function GuildieCrafts_IsJewelcraftingWorkshop(room)
    return GuildieCrafts_GetRoomProfession(room) == "jewelcrafting"
end

function GuildieCrafts_IsWorkshopFullySupported(room)
    return GuildieCrafts_IsProfessionEnabled(GuildieCrafts_GetRoomProfession(room))
end

function GuildieCrafts_GetUnsupportedWorkshopMessage(room)
    local profession = GuildieCrafts_GetProfessionLabel(GuildieCrafts_GetRoomProfession(room))
    if GuildieCrafts_IsProfessionEnabled(GuildieCrafts_GetRoomProfession(room)) then
        return "This workshop is not fully configured yet."
    end
    return profession .. " workshops are not available yet."
end

function GuildieCrafts_GetRoomCrafterSingular(room)
    local labels = {
        jewelcrafting = "Jewelcrafter",
        tailoring = "Tailor",
        leatherworking = "Leatherworker",
        blacksmithing = "Blacksmith",
    }
    return labels[GuildieCrafts_GetRoomProfession(room)] or "Crafter"
end

function GuildieCrafts_GetRoomCrafterShortLabel(room)
    local labels = {
        jewelcrafting = "JC",
        tailoring = "Tailor",
        leatherworking = "LW",
        blacksmithing = "BS",
    }
    return labels[GuildieCrafts_GetRoomProfession(room)] or "Crafter"
end

function GuildieCrafts_GetRoomScarceMaterial(room)
    if not room then
        return nil
    end
    return GuildieCrafts_GetScarceMaterialForProfession(GuildieCrafts_GetRoomProfession(room))
end

function GuildieCrafts_GetRoomScarceMaterialName(room)
    local material = GuildieCrafts_GetRoomScarceMaterial(room)
    return material and material.name or nil
end
