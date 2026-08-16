-- Workshop metadata: expansion, phase, and profession types.

local ADDON_NAME = ...

GuildieCraftsTest_EXPANSION_PHASES = {
    {
        expansion = "TBC",
        label = "TBC",
        enabled = true,
        phases = {
            { phase = "Phase 3", label = "Phase 3", enabled = true },
            { phase = "Phase 4", label = "Phase 4 (soon)", enabled = false },
        },
    },
    {
        expansion = "WOTLK",
        label = "WOTLK",
        enabled = false,
        phases = {},
    },
}

GuildieCraftsTest_PROFESSIONS = {
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
    leatherworking = 32549,
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

function GuildieCraftsTest_GetDefaultExpansion()
    return DEFAULT_EXPANSION
end

function GuildieCraftsTest_GetDefaultPhase()
    return DEFAULT_PHASE
end

local function NormalizePhaseEntry(phaseEntry)
    if type(phaseEntry) == "table" then
        return phaseEntry.phase, phaseEntry.label or phaseEntry.phase, phaseEntry.enabled ~= false
    end
    return phaseEntry, phaseEntry, true
end

function GuildieCraftsTest_GetExpansionPhaseOptions()
    local options = {}
    for _, entry in ipairs(GuildieCraftsTest_EXPANSION_PHASES) do
        for _, phaseEntry in ipairs(entry.phases or {}) do
            local phase, label = NormalizePhaseEntry(phaseEntry)
            table.insert(options, {
                expansion = entry.expansion,
                phase = phase,
                label = entry.label .. " — " .. label,
            })
        end
    end
    return options
end

function GuildieCraftsTest_GetExpansionOptions()
    local options = {}
    for _, entry in ipairs(GuildieCraftsTest_EXPANSION_PHASES) do
        table.insert(options, {
            expansion = entry.expansion,
            label = entry.label,
            enabled = entry.enabled ~= false,
        })
    end
    return options
end

function GuildieCraftsTest_GetPhaseOptions(expansionId)
    local phases = {}
    for _, entry in ipairs(GuildieCraftsTest_EXPANSION_PHASES) do
        if entry.expansion == expansionId then
            for _, phaseEntry in ipairs(entry.phases or {}) do
                local phase, label, enabled = NormalizePhaseEntry(phaseEntry)
                table.insert(phases, {
                    phase = phase,
                    label = label,
                    enabled = enabled,
                })
            end
            break
        end
    end
    return phases
end

function GuildieCraftsTest_IsExpansionEnabled(expansionId)
    for _, entry in ipairs(GuildieCraftsTest_EXPANSION_PHASES) do
        if entry.expansion == expansionId then
            return entry.enabled ~= false
        end
    end
    return false
end

function GuildieCraftsTest_GetProfessionOptions()
    return GuildieCraftsTest_PROFESSIONS
end

function GuildieCraftsTest_IsProfessionEnabled(professionId)
    for _, profession in ipairs(GuildieCraftsTest_PROFESSIONS) do
        if profession.id == professionId then
            return profession.enabled == true
        end
    end
    return false
end

function GuildieCraftsTest_GetProfessionLabel(professionId)
    for _, profession in ipairs(GuildieCraftsTest_PROFESSIONS) do
        if profession.id == professionId then
            return profession.label
        end
    end
    return professionId or "Unknown"
end

function GuildieCraftsTest_GetCrafterLabel(professionId)
    return CRAFTER_LABELS[professionId] or "Crafters"
end

function GuildieCraftsTest_GetProfessionIcon(professionId)
    local spellId = PROFESSION_SPELL_IDS[professionId]
    local resolved = ResolveSpellIcon(spellId)
    if resolved then
        return resolved
    end
    return PROFESSION_ICONS[professionId] or DEFAULT_WORKSHOP_ICON
end

function GuildieCraftsTest_GetDefaultWorkshopIcon()
    return DEFAULT_WORKSHOP_ICON
end

function GuildieCraftsTest_GetDefaultWorkshopPortrait()
    return DEFAULT_WORKSHOP_PORTRAIT
end

function GuildieCraftsTest_GetWorkshopPortraitIcon(room)
    if not room then
        return DEFAULT_WORKSHOP_PORTRAIT
    end
    return GuildieCraftsTest_GetProfessionPortraitIcon(GuildieCraftsTest_GetRoomProfession(room))
end

function GuildieCraftsTest_GetProfessionPortraitIcon(professionId)
    if not professionId then
        return DEFAULT_WORKSHOP_PORTRAIT
    end
    local spellId = PROFESSION_SPELL_IDS[professionId]
    local resolved = ResolveSpellIcon(spellId)
    if resolved then
        return resolved
    end
    return PROFESSION_ICONS[professionId] or DEFAULT_WORKSHOP_PORTRAIT
end

function GuildieCraftsTest_FormatWorkshopScope(room)
    if not room then
        return ""
    end
    local expansion = room.expansion or DEFAULT_EXPANSION
    local phase = room.phase or DEFAULT_PHASE
    local profession = GuildieCraftsTest_GetProfessionLabel(room.profession or "jewelcrafting")
    return string.format("%s %s · %s", expansion, phase, profession)
end

function GuildieCraftsTest_ValidateWorkshopDefinition(name, expansion, phase, profession)
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
    if not GuildieCraftsTest_IsProfessionEnabled(profession) then
        return false, GuildieCraftsTest_GetProfessionLabel(profession)
            .. " workshops are coming in a future release."
    end
    if not GuildieCraftsTest_IsExpansionEnabled(expansion) then
        return false, "That expansion is not available yet."
    end

    local validPhase = false
    for _, option in ipairs(GuildieCraftsTest_GetPhaseOptions(expansion)) do
        if option.phase == phase and option.enabled ~= false then
            validPhase = true
            break
        end
    end
    if not validPhase then
        return false, "Select a valid phase."
    end

    return true
end

function GuildieCraftsTest_GetRoomProfession(room)
    if not room then
        return "jewelcrafting"
    end
    return room.profession or "jewelcrafting"
end

function GuildieCraftsTest_IsJewelcraftingWorkshop(room)
    return GuildieCraftsTest_GetRoomProfession(room) == "jewelcrafting"
end

function GuildieCraftsTest_IsWorkshopFullySupported(room)
    return GuildieCraftsTest_IsProfessionEnabled(GuildieCraftsTest_GetRoomProfession(room))
end

function GuildieCraftsTest_GetUnsupportedWorkshopMessage(room)
    local profession = GuildieCraftsTest_GetProfessionLabel(GuildieCraftsTest_GetRoomProfession(room))
    if GuildieCraftsTest_IsProfessionEnabled(GuildieCraftsTest_GetRoomProfession(room)) then
        return "This workshop is not fully configured yet."
    end
    return profession .. " workshops are not available yet."
end

function GuildieCraftsTest_GetRoomCrafterSingular(room)
    local labels = {
        jewelcrafting = "Jewelcrafter",
        tailoring = "Tailor",
        leatherworking = "Leatherworker",
        blacksmithing = "Blacksmith",
    }
    return labels[GuildieCraftsTest_GetRoomProfession(room)] or "Crafter"
end

function GuildieCraftsTest_GetRoomCrafterShortLabel(room)
    local labels = {
        jewelcrafting = "JC",
        tailoring = "Tailor",
        leatherworking = "LW",
        blacksmithing = "BS",
    }
    return labels[GuildieCraftsTest_GetRoomProfession(room)] or "Crafter"
end

function GuildieCraftsTest_GetRoomScarceMaterial(room)
    if not room then
        return nil
    end
    return GuildieCraftsTest_GetScarceMaterialForProfession(GuildieCraftsTest_GetRoomProfession(room))
end

function GuildieCraftsTest_GetRoomScarceMaterialName(room)
    local material = GuildieCraftsTest_GetRoomScarceMaterial(room)
    return material and material.name or nil
end
