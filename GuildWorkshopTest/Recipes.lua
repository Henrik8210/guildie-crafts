GuildWorkshopTest = GuildWorkshopTest or {}

local PROFESSION_TRADE_SKILLS = {
    jewelcrafting = "Jewelcrafting",
    tailoring = "Tailoring",
    leatherworking = "Leatherworking",
    blacksmithing = "Blacksmithing",
}

local scanPending = false
local autoScanSilent = false
local autoScanClose = false
local scanRetryToken = 0
local eventScanQueued = false

local function EnsureDB()
    GuildWorkshopTestDB = GuildWorkshopTestDB or {}
    GuildWorkshopTestDB.recipes = GuildWorkshopTestDB.recipes or { jcReports = {} }
    GuildWorkshopTestDB.recipes.jcReports = GuildWorkshopTestDB.recipes.jcReports or {}
end

local function GetActiveRecipeProfession()
    local room = GuildWorkshopTest_GetActiveRoom()
    if room then
        return GuildWorkshopTest_GetRoomProfession(room)
    end
    return "jewelcrafting"
end

local function GetTradeSkillName(professionId)
    return PROFESSION_TRADE_SKILLS[professionId or "jewelcrafting"] or PROFESSION_TRADE_SKILLS.jewelcrafting
end

local function GetProfessionLabel(professionId)
    return GuildWorkshopTest_GetProfessionLabel(professionId or "jewelcrafting")
end

function GuildWorkshopTest_ShouldShareRecipes()
    return GuildWorkshopTest_ShouldShareStock()
end

function GuildWorkshopTest_IsJewelcraftingOpen()
    return GuildWorkshopTest_IsTradeSkillOpen("jewelcrafting")
end

function GuildWorkshopTest_IsTradeSkillOpen(professionId)
    if not GetNumTradeSkills then
        return false
    end
    local num = GetNumTradeSkills() or 0
    if num <= 0 then
        return false
    end
    professionId = professionId or GetActiveRecipeProfession()
    local expected = GetTradeSkillName(professionId)
    if GetTradeSkillLine then
        local line = GetTradeSkillLine()
        if line and line ~= expected and not line:find(expected:sub(1, 5)) then
            return false
        end
    end
    return true
end

local tradeSkillSpellCache = {}

local function GetTradeSkillSpellRef(professionId)
    professionId = professionId or GetActiveRecipeProfession()
    if tradeSkillSpellCache[professionId] then
        return tradeSkillSpellCache[professionId]
    end

    local keyword = GetTradeSkillName(professionId)
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, numSpells = GetSpellTabInfo(tab)
            if offset and numSpells then
                for i = offset + 1, offset + numSpells do
                    local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                    if name and name:find(keyword:sub(1, 5)) then
                        local spellId
                        if GetSpellBookItemInfo then
                            _, spellId = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
                        end
                        if spellId and GetSpellInfo then
                            local resolved = GetSpellInfo(spellId)
                            if resolved then
                                tradeSkillSpellCache[professionId] = resolved
                                return tradeSkillSpellCache[professionId]
                            end
                        end
                        tradeSkillSpellCache[professionId] = name
                        return tradeSkillSpellCache[professionId]
                    end
                end
            end
        end
    end

    tradeSkillSpellCache[professionId] = keyword
    return tradeSkillSpellCache[professionId]
end

local function GetJewelcraftingSpellRef()
    return GetTradeSkillSpellRef("jewelcrafting")
end

function GuildWorkshopTest_HandleRecipesRefreshClick()
    local professionId = GetActiveRecipeProfession()
    if GuildWorkshopTest_IsTradeSkillOpen(professionId) then
        GuildWorkshopTest_RefreshRecipesFromMacro(false)
        return
    end

    local spellRef = GetTradeSkillSpellRef(professionId)
    if CastSpellByName then
        CastSpellByName(spellRef)
    end
    GuildWorkshopTest_RefreshRecipesFromMacro(true)
end

function GuildWorkshopTest_InitRecipesRefreshButton(btn)
    if not btn or btn._GuildWorkshopRefreshInit then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    btn._GuildWorkshopRefreshInit = true
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/run GuildWorkshopTest_HandleRecipesRefreshClick()")
end

function GuildWorkshopTest_RefreshRecipesSyncOnly()
    if GuildWorkshopTest.Sync then
        GuildWorkshopTest.Sync:RequestSync()
    end
    if GuildWorkshopTest.UI then
        GuildWorkshopTest_RefreshUI()
    end
    print("|cff00ccffGuildWorkshopTest|r Recipe list refreshed.")
end

local function MatchGemByName(name)
    if not name or name == "" then
        return nil
    end
    local gem = GuildWorkshopTest_GemByName[name]
    if gem then
        return gem
    end
    if strlower then
        for gemName, entry in pairs(GuildWorkshopTest_GemByName or {}) do
            if strlower(gemName) == strlower(name) then
                return entry
            end
        end
    end
    return nil
end

local function ItemIdFromLink(link)
    if not link then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local function MatchCraftByName(name)
    if not name or name == "" then
        return nil
    end
    local craft = GuildWorkshopTest_GetCraftByName(name)
    if craft then
        return craft
    end
    if strlower then
        for craftName, entry in pairs(GuildWorkshopTest_CraftByName or {}) do
            if strlower(craftName) == strlower(name) then
                return entry
            end
        end
    end
    return nil
end

function GuildWorkshopTest_ScanOpenTradeSkill()
    local known = {}
    if not GetNumTradeSkills or not GetTradeSkillInfo then
        return known, 0
    end

    local num = GetNumTradeSkills() or 0
    if num <= 0 then
        return known, 0
    end

    for i = 1, num do
        local name, skillType = GetTradeSkillInfo(i)
        if name and skillType ~= "header" then
            local itemId = ItemIdFromLink(GetTradeSkillItemLink and GetTradeSkillItemLink(i))
            if not itemId then
                local gem = MatchGemByName(name)
                itemId = gem and gem.itemId
            end
            if not itemId then
                local craft = MatchCraftByName(name)
                itemId = craft and craft.itemId
            end
            if itemId and GuildWorkshopTest_IsTrackedRecipeItemId(itemId) then
                known[itemId] = true
            end
        end
    end

    return known, num
end

local function StoreLocalRecipeReport(itemIds)
    EnsureDB()
    GuildWorkshopTestDB.recipes.jcReports[UnitName("player")] = {
        itemIds = itemIds,
        updatedAt = time(),
    }
end

local function CountKnown(itemIds)
    local count = 0
    for _ in pairs(itemIds or {}) do
        count = count + 1
    end
    return count
end

local function FinishAutoScanClose()
    autoScanClose = false
    autoScanSilent = false
end

local function ApplyRecipeScanResult(known, numSkills, source)
    StoreLocalRecipeReport(known)
    GuildWorkshopTest.Sync:BroadcastRecipes(known)
    if GuildWorkshopTest.UI then
        GuildWorkshopTest_RefreshUI()
    end

    local professionId = GetActiveRecipeProfession()
    local professionLabel = GetProfessionLabel(professionId)
    local knownCount = CountKnown(known)
    if scanPending then
        if numSkills <= 0 then
            print("|cffff0000GuildWorkshopTest|r Could not read recipes. Open your "
                .. professionLabel .. " window and try again.")
        elseif knownCount == 0 then
            print("|cff00ccffGuildWorkshopTest|r Scanned " .. professionLabel
                .. " (" .. numSkills .. " entries). No tracked recipes found yet.")
        else
            print("|cff00ccffGuildWorkshopTest|r Scanned and shared " .. knownCount
                .. " recipes with the workshop.")
        end
    elseif source == "login" and knownCount > 0 then
        print("|cff00ccffGuildWorkshopTest|r Shared " .. knownCount .. " recipes with the workshop.")
    end

    scanPending = false
    FinishAutoScanClose()
end

local function RunRecipeScan(source)
    if not GuildWorkshopTest_ShouldShareRecipes() then
        scanPending = false
        FinishAutoScanClose()
        return
    end

    local known, numSkills = GuildWorkshopTest_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, source)
        return
    end

    if source == "retry" then
        return
    end
end

local function ScheduleRecipeScan(source, delay)
    scanRetryToken = scanRetryToken + 1
    local token = scanRetryToken
    local function attempt(retryDelay, retrySource)
        if token ~= scanRetryToken then
            return
        end
        if not GuildWorkshopTest_ShouldShareRecipes() then
            scanPending = false
            FinishAutoScanClose()
            return
        end

        local known, numSkills = GuildWorkshopTest_ScanOpenTradeSkill()
        if numSkills > 0 then
            ApplyRecipeScanResult(known, numSkills, source)
            return
        end

        if retrySource == "retry1" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, function()
                    attempt(0, "retry2")
                end)
            end
            return
        end

        if retrySource == "retry2" then
            if scanPending and not autoScanSilent then
                print("|cffff0000GuildWorkshopTest|r Could not read recipes. Open your "
                    .. GetProfessionLabel(GetActiveRecipeProfession())
                    .. " window and try again.")
            end
            scanPending = false
            FinishAutoScanClose()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(delay or 0.15, function()
            attempt(0, "retry1")
        end)
    else
        attempt(0, "retry1")
    end
end

function GuildWorkshopTest_ScanAndShareRecipes()
    EnsureDB()
    if not GuildWorkshopTest_ShouldShareRecipes() then
        local crafters = string.lower(GuildWorkshopTest_GetCrafterLabel(GetActiveRecipeProfession()))
        return false, "Only promoted " .. crafters .. " can share recipes."
    end

    local known, numSkills = GuildWorkshopTest_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, "manual")
        return true
    end

    print("|cff00ccffGuildWorkshopTest|r Open "
        .. GetProfessionLabel(GetActiveRecipeProfession())
        .. ", then click Refresh on the Recipes tab.")
    return false, "closed"
end

function GuildWorkshopTest_ShareWorkshopRecipes()
    EnsureDB()
    if not GuildWorkshopTest_ShouldShareRecipes() then
        return
    end
    local player = UnitName("player")
    local report = GuildWorkshopTestDB.recipes.jcReports[player]
    if report and report.itemIds then
        GuildWorkshopTest.Sync:BroadcastRecipes(report.itemIds)
    end
end

function GuildWorkshopTest_AutoScanRecipes(silent)
    if not GuildWorkshopTest_ShouldShareRecipes() then
        return
    end

    local professionId = GetActiveRecipeProfession()
    if not GuildWorkshopTest_IsTradeSkillOpen(professionId) then
        if not silent then
            print("|cff00ccffGuildWorkshopTest|r Open "
                .. GetProfessionLabel(professionId)
                .. ", then click Refresh on the Recipes tab.")
        end
        return
    end

    autoScanSilent = silent and true or false
    autoScanClose = false
    if not silent then
        scanPending = true
    end
    ScheduleRecipeScan(silent and "login" or "manual", 0.1)
end

function GuildWorkshopTest_RequestRecipeScan()
    return GuildWorkshopTest_ScanAndShareRecipes()
end

function GuildWorkshopTest_ApplyRecipeReport(player, itemIds)
    EnsureDB()
    GuildWorkshopTestDB.recipes.jcReports[player] = {
        itemIds = itemIds,
        updatedAt = time(),
    }
    if GuildWorkshopTest.UI then
        GuildWorkshopTest_RefreshUI()
    end
end

function GuildWorkshopTest_GetRecipeCoverage(room, tier)
    EnsureDB()
    local coverage = {}
    if not room then
        return coverage
    end

    local profession = GuildWorkshopTest_GetRoomProfession(room)
    if profession ~= "jewelcrafting" then
        for _, craft in ipairs(GuildWorkshopTest_GetCraftCatalog(profession)) do
            local jcs = {}
            for _, crafterName in ipairs(GuildWorkshopTest_GetWorkshopStockContributors(room)) do
                local report = GuildWorkshopTestDB.recipes.jcReports[crafterName]
                if report and report.itemIds and report.itemIds[craft.itemId] then
                    table.insert(jcs, crafterName)
                end
            end
            table.insert(coverage, {
                craft = craft,
                jcs = jcs,
            })
        end
        return coverage
    end

    for _, gem in ipairs(GuildWorkshopTest_GetRecipeGems(tier or "epic")) do
        local jcs = {}
        for _, jcName in ipairs(GuildWorkshopTest_GetWorkshopStockContributors(room)) do
            local report = GuildWorkshopTestDB.recipes.jcReports[jcName]
            if report and report.itemIds and report.itemIds[gem.itemId] then
                table.insert(jcs, jcName)
            end
        end
        table.insert(coverage, {
            gem = gem,
            jcs = jcs,
        })
    end
    return coverage
end

function GuildWorkshopTest_WorkshopHasRecipeForGem(gemName)
    if not gemName or gemName == "None" then
        return true
    end

    local gem = GuildWorkshopTest_GemByName[gemName]
    if not gem or gem.raw or not gem.itemId then
        return true
    end

    local room = GuildWorkshopTest_GetActiveRoom()
    if not room then
        return true
    end

    EnsureDB()
    local contributors = GuildWorkshopTest_GetWorkshopStockContributors(room)
    if #contributors == 0 then
        return false
    end

    for _, jcName in ipairs(contributors) do
        local report = GuildWorkshopTestDB.recipes.jcReports[jcName]
        if report and report.itemIds and report.itemIds[gem.itemId] then
            return true
        end
    end

    return false
end

local RECIPE_KNOWN_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t"
local RECIPE_MISSING_ICON = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14:14|t"

function GuildWorkshopTest_GetRecipeIndicatorText(gemName)
    if not gemName or gemName == "None" then
        return ""
    end

    local gem = GuildWorkshopTest_GemByName and GuildWorkshopTest_GemByName[gemName]
    if not gem or gem.raw or not gem.itemId then
        return ""
    end

    if GuildWorkshopTest_WorkshopHasRecipeForGem(gemName) then
        return RECIPE_KNOWN_ICON .. " "
    end

    return RECIPE_MISSING_ICON .. " "
end

function GuildWorkshopTest_FormatGemDropdownLabel(gemName)
    if not gemName or gemName == "None" then
        return nil
    end

    local indicator = GuildWorkshopTest_GetRecipeIndicatorText(gemName)
    if indicator == "" then
        return gemName
    end

    return indicator .. gemName
end

local function QueuePassiveRecipeScan()
    if not GuildWorkshopTest_ShouldShareRecipes() or not GuildWorkshopTest_HasJoinedWorkshop() then
        return
    end
    if scanPending or autoScanSilent or autoScanClose or eventScanQueued then
        return
    end
    eventScanQueued = true

    local function run()
        eventScanQueued = false
        if scanPending or autoScanSilent or autoScanClose then
            return
        end
        if not GuildWorkshopTest_ShouldShareRecipes() or not GuildWorkshopTest_IsTradeSkillOpen(GetActiveRecipeProfession()) then
            return
        end
        local known, numSkills = GuildWorkshopTest_ScanOpenTradeSkill()
        if numSkills <= 0 then
            return
        end
        StoreLocalRecipeReport(known)
        GuildWorkshopTest.Sync:BroadcastRecipes(known)
        if GuildWorkshopTest.UI then
            GuildWorkshopTest_RefreshUI()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.75, run)
    else
        run()
    end
end

local function OnTradeSkillEvent()
    if scanPending or autoScanSilent or autoScanClose then
        ScheduleRecipeScan(autoScanSilent and "login" or "manual", 0.1)
        return
    end
    QueuePassiveRecipeScan()
end

function GuildWorkshopTest_RefreshRecipesFromMacro(delayScan)
    if not GuildWorkshopTest_ShouldShareRecipes() then
        GuildWorkshopTest_RefreshRecipesSyncOnly()
        return
    end

    if delayScan then
        scanPending = true
        print("|cff00ccffGuildWorkshopTest|r Opening "
            .. GetProfessionLabel(GetActiveRecipeProfession()) .. "…")
        ScheduleRecipeScan("manual", 0.75)
        return
    end

    local known, numSkills = GuildWorkshopTest_ScanOpenTradeSkill()
    if numSkills > 0 then
        ApplyRecipeScanResult(known, numSkills, "manual")
    else
        print("|cffff0000GuildWorkshopTest|r Open your "
            .. GetProfessionLabel(GetActiveRecipeProfession())
            .. " window, then click Refresh again.")
    end
end

local recipeWatcher

function GuildWorkshopTest_InitRecipeEvents()
    if recipeWatcher then
        return
    end
    recipeWatcher = CreateFrame("Frame")
    recipeWatcher:RegisterEvent("TRADE_SKILL_SHOW")
    recipeWatcher:RegisterEvent("TRADE_SKILL_UPDATE")
    recipeWatcher:SetScript("OnEvent", OnTradeSkillEvent)
end
