GuildieCraftsTest = GuildieCraftsTest or {}

local function EnsureDB()
    GuildieCraftsTestDB = GuildieCraftsTestDB or {}
    GuildieCraftsTestDB.stock = GuildieCraftsTestDB.stock or {
        bags = {},
        bank = {},
        jcReports = {},
        guildBank = { byProfession = {} },
    }
    GuildieCraftsTestDB.stock.guildBank = GuildieCraftsTestDB.stock.guildBank or { byProfession = {} }
    GuildieCraftsTestDB.stock.guildBank.byProfession = GuildieCraftsTestDB.stock.guildBank.byProfession or {}
end

local function GetActiveStockProfession()
    local room = GuildieCraftsTest_GetActiveRoom()
    if room then
        return GuildieCraftsTest_GetRoomProfession(room)
    end
    return "jewelcrafting"
end

local function EmptyCounts(professionId)
    professionId = professionId or GetActiveStockProfession()
    local counts = {}
    for _, entry in ipairs(GuildieCraftsTest_GetStockCatalog(professionId)) do
        counts[entry.itemId] = 0
    end
    return counts
end

local function ItemIdFromLink(link)
    if not link then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local function AddItemToCounts(itemId, stackCount, counts)
    if itemId and counts[itemId] ~= nil then
        counts[itemId] = counts[itemId] + (stackCount or 1)
    end
end

local function AddLinkToCounts(link, counts, stackCount)
    AddItemToCounts(ItemIdFromLink(link), stackCount, counts)
end

local function MergeCounts(into, from)
    for itemId, count in pairs(from or {}) do
        into[itemId] = (into[itemId] or 0) + count
    end
    return into
end

local function GetContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end
    if GetContainerNumSlots then
        return GetContainerNumSlots(bag) or 0
    end
    return 0
end

local function ScanContainerSlot(bag, slot, counts)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then
            local link = info.hyperlink
            if not link and info.iconFileID and C_Container.GetContainerItemLink then
                link = C_Container.GetContainerItemLink(bag, slot)
            end
            AddLinkToCounts(link, counts, info.stackCount)
            return
        end
    end

    if GetContainerItemInfo then
        local link = GetContainerItemLink and GetContainerItemLink(bag, slot)
        local _, stackCount = GetContainerItemInfo(bag, slot)
        AddLinkToCounts(link, counts, stackCount)
        return
    end

    if GetContainerItemLink then
        AddLinkToCounts(GetContainerItemLink(bag, slot), counts, 1)
    end
end

local function ScanBagRange(firstBag, lastBag, counts)
    for bag = firstBag, lastBag do
        local slots = GetContainerSlots(bag)
        for slot = 1, slots do
            ScanContainerSlot(bag, slot, counts)
        end
    end
end

function GuildieCraftsTest_ScanBagsForGems()
    local professionId = GetActiveStockProfession()
    local counts = EmptyCounts(professionId)
    ScanBagRange(0, 4, counts)

    EnsureDB()
    GuildieCraftsTestDB.stock.bags = counts
    GuildieCraftsTestDB.stock.bagsUpdated = time()
    return counts
end

local function IsBankAccessible()
    if BankFrame and BankFrame.IsShown and BankFrame:IsShown() then
        return true
    end
    return GetContainerSlots(5) > 0
end

function GuildieCraftsTest_IsBankAccessible()
    return IsBankAccessible()
end

function GuildieCraftsTest_GetBankStockNote()
    EnsureDB()
    if IsBankAccessible() then
        return nil
    end
    local materialLabel = GuildieCraftsTest_IsJewelcraftingWorkshop(GuildieCraftsTest_GetActiveRoom())
        and "bank gems"
        or "bank materials"
    if GuildieCraftsTestDB.stock.bankUpdated then
        return "bank included from last visit"
    end
    return "open your bank once to include " .. materialLabel
end

function GuildieCraftsTest_ScanPersonalBankForGems()
    EnsureDB()
    local professionId = GetActiveStockProfession()
    if not IsBankAccessible() then
        GuildieCraftsTestDB.stock.bank = GuildieCraftsTestDB.stock.bank or EmptyCounts(professionId)
        return GuildieCraftsTestDB.stock.bank
    end

    local counts = EmptyCounts(professionId)
    ScanBagRange(5, 11, counts)

    GuildieCraftsTestDB.stock.bank = counts
    GuildieCraftsTestDB.stock.bankUpdated = time()
    return counts
end

function GuildieCraftsTest_GetCombinedPersonalStock()
    EnsureDB()
    local professionId = GetActiveStockProfession()
    GuildieCraftsTestDB.stock.bags = GuildieCraftsTestDB.stock.bags or EmptyCounts(professionId)
    GuildieCraftsTestDB.stock.bank = GuildieCraftsTestDB.stock.bank or EmptyCounts(professionId)
    return MergeCounts(MergeCounts(EmptyCounts(professionId), GuildieCraftsTestDB.stock.bags), GuildieCraftsTestDB.stock.bank)
end

function GuildieCraftsTest_RefreshLocalStock()
    GuildieCraftsTest_ScanBagsForGems()
    GuildieCraftsTest_ScanPersonalBankForGems()
    if GuildieCraftsTest_IsGuildBankAccessible and GuildieCraftsTest_IsGuildBankAccessible() then
        GuildieCraftsTest_ScanGuildBankForMaterials()
    end
    if GuildieCraftsTest_ShouldShareStock() then
        GuildieCraftsTest_ShareWorkshopStock()
    end
    if GuildieCraftsTest.UI and GuildieCraftsTest.UI.frame then
        GuildieCraftsTest.UI:Refresh()
    end
end

function GuildieCraftsTest_ShareWorkshopStock()
    EnsureDB()
    if not IsInGuild() or not GuildieCraftsTest_ShouldShareStock() then
        return
    end

    GuildieCraftsTest.Sync:BroadcastStock(GuildieCraftsTest_GetCombinedPersonalStock(), "jc")
end

function GuildieCraftsTest_GetStockCounts(source)
    EnsureDB()
    if source == "bags" then
        return GuildieCraftsTestDB.stock.bags or {}
    end
    if source == "bank" then
        return GuildieCraftsTestDB.stock.bank or {}
    end
    if source == "personal" then
        return GuildieCraftsTest_GetCombinedPersonalStock()
    end
    return {}
end

function GuildieCraftsTest_GetWorkshopStockReports(room)
    EnsureDB()
    local reports = {}
    if not room then
        return reports
    end

    for _, name in ipairs(GuildieCraftsTest_GetWorkshopStockContributors(room)) do
        local report = GuildieCraftsTestDB.stock.jcReports[name]
        if report then
            reports[name] = report
        end
    end
    return reports
end

function GuildieCraftsTest_GetAggregatedWorkshopStock(room)
    EnsureDB()
    local professionId = room and GuildieCraftsTest_GetRoomProfession(room) or "jewelcrafting"
    local totals = EmptyCounts(professionId)
    local player = UnitName("player")

    for _, jcName in ipairs(GuildieCraftsTest_GetWorkshopStockContributors(room)) do
        if jcName == player then
            MergeCounts(totals, GuildieCraftsTest_GetCombinedPersonalStock())
        else
            local report = GuildieCraftsTestDB.stock.jcReports[jcName]
            if report then
                MergeCounts(totals, report.counts)
            end
        end
    end
    MergeCounts(totals, GuildieCraftsTest_GetGuildBankStockForRoom(room))
    return totals
end

function GuildieCraftsTest_ApplyStockReport(player, counts, source, professionId)
    EnsureDB()
    if source == "gb" and professionId then
        GuildieCraftsTestDB.stock.guildBank.byProfession[professionId] = {
            counts = counts,
            updatedAt = time(),
            scannedBy = player,
        }
    elseif source == "jc" or source == "bags" then
        GuildieCraftsTestDB.stock.jcReports[player] = {
            counts = counts,
            updatedAt = time(),
        }
    end
    if GuildieCraftsTest.UI and GuildieCraftsTest.UI.frame then
        GuildieCraftsTest.UI:Refresh()
    end
end

function GuildieCraftsTest_GetStockListing(counts, professionId)
    professionId = professionId or GetActiveStockProfession()
    local lines = {}
    for _, entry in ipairs(GuildieCraftsTest_GetStockCatalog(professionId)) do
        local count = counts[entry.itemId] or 0
        if count > 0 then
            table.insert(lines, {
                name = entry.name,
                count = count,
                itemId = entry.itemId,
                raw = true,
                rare = entry.rare,
            })
        end
    end
    table.sort(lines, function(a, b)
        if (a.rare or false) ~= (b.rare or false) then
            return not a.rare
        end
        return a.name < b.name
    end)
    return lines
end

local stockEventFrame
local bankScanQueued = false
local guildBankScanQueued = false
local GUILD_BANK_SLOTS = 98

local function IsGuildBankAccessible()
    if GuildBankFrame and GuildBankFrame.IsShown and GuildBankFrame:IsShown() then
        return true
    end
    return false
end

function GuildieCraftsTest_IsGuildBankAccessible()
    return IsGuildBankAccessible()
end

function GuildieCraftsTest_GetGuildBankStockForRoom(room)
    EnsureDB()
    if not room then
        return {}
    end
    local professionId = GuildieCraftsTest_GetRoomProfession(room)
    local entry = GuildieCraftsTestDB.stock.guildBank.byProfession[professionId]
    return (entry and entry.counts) or EmptyCounts(professionId)
end

function GuildieCraftsTest_GetGuildBankStockNote(room)
    EnsureDB()
    if not room then
        return nil
    end
    if IsGuildBankAccessible() then
        return nil
    end
    local professionId = GuildieCraftsTest_GetRoomProfession(room)
    local entry = GuildieCraftsTestDB.stock.guildBank.byProfession[professionId]
    if entry and entry.updatedAt then
        return "included from last visit"
    end
    return "open the guild bank once to include guild bank materials"
end

local function ScanGuildBankTab(tabIndex, countsByProfession)
    for slot = 1, GUILD_BANK_SLOTS do
        local link = GetGuildBankItemLink and GetGuildBankItemLink(tabIndex, slot)
        local _, stackCount = GetGuildBankItemInfo(tabIndex, slot)
        local itemId = ItemIdFromLink(link)
        if itemId then
            for _, counts in pairs(countsByProfession) do
                AddItemToCounts(itemId, stackCount, counts)
            end
        end
    end
end

local function BuildGuildBankProfessionCounts()
    local countsByProfession = {}
    for _, prof in ipairs(GuildieCraftsTest_PROFESSIONS or {}) do
        if prof.enabled and GuildieCraftsTest_IsProfessionEnabled(prof.id) then
            countsByProfession[prof.id] = EmptyCounts(prof.id)
        end
    end
    return countsByProfession
end

local function StoreAndShareGuildBankScans(countsByProfession)
    EnsureDB()
    local scannedBy = UnitName("player")
    local updatedAt = time()

    for professionId, counts in pairs(countsByProfession) do
        GuildieCraftsTestDB.stock.guildBank.byProfession[professionId] = {
            counts = counts,
            updatedAt = updatedAt,
            scannedBy = scannedBy,
        }
        if IsInGuild() then
            GuildieCraftsTest.Sync:BroadcastStock(counts, "gb-" .. professionId)
        end
    end

    if GuildieCraftsTest.UI and GuildieCraftsTest.UI.frame then
        GuildieCraftsTest.UI:Refresh()
    end
end

function GuildieCraftsTest_ScanGuildBankForMaterials()
    if not IsGuildBankAccessible() then
        EnsureDB()
        local professionId = GetActiveStockProfession()
        local entry = GuildieCraftsTestDB.stock.guildBank.byProfession[professionId]
        return (entry and entry.counts) or EmptyCounts(professionId)
    end

    if not IsInGuild() then
        return {}
    end

    local countsByProfession = BuildGuildBankProfessionCounts()
    local numTabs = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0

    for tab = 1, numTabs do
        local _, _, isViewable = GetGuildBankTabInfo(tab)
        if isViewable then
            ScanGuildBankTab(tab, countsByProfession)
        end
    end

    StoreAndShareGuildBankScans(countsByProfession)
    return countsByProfession[GetActiveStockProfession()] or {}
end

local function QueueGuildBankStockRefresh()
    if guildBankScanQueued then
        return
    end
    guildBankScanQueued = true

    local function run()
        guildBankScanQueued = false
        if not IsGuildBankAccessible() then
            return
        end

        local numTabs = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0
        if QueryGuildBankTab then
            for tab = 1, numTabs do
                local _, _, isViewable = GetGuildBankTabInfo(tab)
                if isViewable then
                    QueryGuildBankTab(tab)
                end
            end
        end

        local function doScan()
            GuildieCraftsTest_ScanGuildBankForMaterials()
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, doScan)
        else
            doScan()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, run)
    else
        run()
    end
end

local function QueueBankStockRefresh()
    if bankScanQueued then
        return
    end
    bankScanQueued = true

    local function run()
        bankScanQueued = false
        if not IsBankAccessible() then
            return
        end
        GuildieCraftsTest_ScanPersonalBankForGems()
        GuildieCraftsTest_ScanBagsForGems()
        if GuildieCraftsTest_ShouldShareStock() then
            GuildieCraftsTest_ShareWorkshopStock()
        end
        if GuildieCraftsTest.UI and GuildieCraftsTest.UI.frame then
            GuildieCraftsTest.UI:Refresh()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, run)
    else
        run()
    end
end

function GuildieCraftsTest_InitStockEvents()
    if stockEventFrame then
        return
    end

    stockEventFrame = CreateFrame("Frame")
    stockEventFrame:RegisterEvent("BANKFRAME_OPENED")
    stockEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    stockEventFrame:RegisterEvent("GUILDBANKFRAME_OPENED")
    stockEventFrame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
    stockEventFrame:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then
            QueueBankStockRefresh()
        elseif event == "GUILDBANKFRAME_OPENED" or event == "GUILDBANKBAGSLOTS_CHANGED" then
            QueueGuildBankStockRefresh()
        end
    end)
end
