GuildWorkshopTest = GuildWorkshopTest or {}

local function EnsureDB()
    GuildWorkshopTestDB = GuildWorkshopTestDB or {}
    GuildWorkshopTestDB.stock = GuildWorkshopTestDB.stock or {
        bags = {},
        bank = {},
        jcReports = {},
    }
end

local function GetActiveStockProfession()
    local room = GuildWorkshopTest_GetActiveRoom()
    if room then
        return GuildWorkshopTest_GetRoomProfession(room)
    end
    return "jewelcrafting"
end

local function EmptyCounts(professionId)
    professionId = professionId or GetActiveStockProfession()
    local counts = {}
    for _, entry in ipairs(GuildWorkshopTest_GetStockCatalog(professionId)) do
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

function GuildWorkshopTest_ScanBagsForGems()
    local professionId = GetActiveStockProfession()
    local counts = EmptyCounts(professionId)
    ScanBagRange(0, 4, counts)

    EnsureDB()
    GuildWorkshopTestDB.stock.bags = counts
    GuildWorkshopTestDB.stock.bagsUpdated = time()
    return counts
end

local function IsBankAccessible()
    if BankFrame and BankFrame.IsShown and BankFrame:IsShown() then
        return true
    end
    return GetContainerSlots(5) > 0
end

function GuildWorkshopTest_IsBankAccessible()
    return IsBankAccessible()
end

function GuildWorkshopTest_GetBankStockNote()
    EnsureDB()
    if IsBankAccessible() then
        return nil
    end
    local materialLabel = GuildWorkshopTest_IsJewelcraftingWorkshop(GuildWorkshopTest_GetActiveRoom())
        and "bank gems"
        or "bank materials"
    if GuildWorkshopTestDB.stock.bankUpdated then
        return "bank included from last visit"
    end
    return "open your bank once to include " .. materialLabel
end

function GuildWorkshopTest_ScanPersonalBankForGems()
    EnsureDB()
    local professionId = GetActiveStockProfession()
    if not IsBankAccessible() then
        GuildWorkshopTestDB.stock.bank = GuildWorkshopTestDB.stock.bank or EmptyCounts(professionId)
        return GuildWorkshopTestDB.stock.bank
    end

    local counts = EmptyCounts(professionId)
    ScanBagRange(5, 11, counts)

    GuildWorkshopTestDB.stock.bank = counts
    GuildWorkshopTestDB.stock.bankUpdated = time()
    return counts
end

function GuildWorkshopTest_GetCombinedPersonalStock()
    EnsureDB()
    local professionId = GetActiveStockProfession()
    GuildWorkshopTestDB.stock.bags = GuildWorkshopTestDB.stock.bags or EmptyCounts(professionId)
    GuildWorkshopTestDB.stock.bank = GuildWorkshopTestDB.stock.bank or EmptyCounts(professionId)
    return MergeCounts(MergeCounts(EmptyCounts(professionId), GuildWorkshopTestDB.stock.bags), GuildWorkshopTestDB.stock.bank)
end

function GuildWorkshopTest_RefreshLocalStock()
    GuildWorkshopTest_ScanBagsForGems()
    GuildWorkshopTest_ScanPersonalBankForGems()
    if GuildWorkshopTest_ShouldShareStock() then
        GuildWorkshopTest_ShareWorkshopStock()
    end
    if GuildWorkshopTest.UI and GuildWorkshopTest.UI.frame then
        GuildWorkshopTest.UI:Refresh()
    end
end

function GuildWorkshopTest_ShareWorkshopStock()
    EnsureDB()
    if not IsInGuild() or not GuildWorkshopTest_ShouldShareStock() then
        return
    end

    GuildWorkshopTest.Sync:BroadcastStock(GuildWorkshopTest_GetCombinedPersonalStock(), "jc")
end

function GuildWorkshopTest_GetStockCounts(source)
    EnsureDB()
    if source == "bags" then
        return GuildWorkshopTestDB.stock.bags or {}
    end
    if source == "bank" then
        return GuildWorkshopTestDB.stock.bank or {}
    end
    if source == "personal" then
        return GuildWorkshopTest_GetCombinedPersonalStock()
    end
    return {}
end

function GuildWorkshopTest_GetWorkshopStockReports(room)
    EnsureDB()
    local reports = {}
    if not room then
        return reports
    end

    for _, name in ipairs(GuildWorkshopTest_GetWorkshopStockContributors(room)) do
        local report = GuildWorkshopTestDB.stock.jcReports[name]
        if report then
            reports[name] = report
        end
    end
    return reports
end

function GuildWorkshopTest_GetAggregatedWorkshopStock(room)
    local professionId = room and GuildWorkshopTest_GetRoomProfession(room) or "jewelcrafting"
    local totals = EmptyCounts(professionId)
    local player = UnitName("player")

    for _, jcName in ipairs(GuildWorkshopTest_GetWorkshopStockContributors(room)) do
        if jcName == player then
            MergeCounts(totals, GuildWorkshopTest_GetCombinedPersonalStock())
        else
            local report = GuildWorkshopTestDB.stock.jcReports[jcName]
            if report then
                MergeCounts(totals, report.counts)
            end
        end
    end
    return totals
end

function GuildWorkshopTest_ApplyStockReport(player, counts, source)
    EnsureDB()
    if source == "jc" or source == "bags" then
        GuildWorkshopTestDB.stock.jcReports[player] = {
            counts = counts,
            updatedAt = time(),
        }
    end
    if GuildWorkshopTest.UI and GuildWorkshopTest.UI.frame then
        GuildWorkshopTest.UI:Refresh()
    end
end

function GuildWorkshopTest_GetStockListing(counts, professionId)
    professionId = professionId or GetActiveStockProfession()
    local lines = {}
    for _, entry in ipairs(GuildWorkshopTest_GetStockCatalog(professionId)) do
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
        GuildWorkshopTest_ScanPersonalBankForGems()
        GuildWorkshopTest_ScanBagsForGems()
        if GuildWorkshopTest_ShouldShareStock() then
            GuildWorkshopTest_ShareWorkshopStock()
        end
        if GuildWorkshopTest.UI and GuildWorkshopTest.UI.frame then
            GuildWorkshopTest.UI:Refresh()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.1, run)
    else
        run()
    end
end

function GuildWorkshopTest_InitStockEvents()
    if stockEventFrame then
        return
    end

    stockEventFrame = CreateFrame("Frame")
    stockEventFrame:RegisterEvent("BANKFRAME_OPENED")
    stockEventFrame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    stockEventFrame:SetScript("OnEvent", function(_, event)
        if event == "BANKFRAME_OPENED" or event == "PLAYERBANKSLOTS_CHANGED" then
            QueueBankStockRefresh()
        end
    end)
end
