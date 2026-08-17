local ADDON_NAME = ...

if not strtrim then
    function strtrim(s)
        return (s:gsub("^%s*(.-)%s*$", "%1"))
    end
end

GuildieCrafts = GuildieCrafts or {}
GuildieCrafts.UI = GuildieCrafts.UI or {}

if GuildWorkshopDB and not GuildieCraftsDB then
    GuildieCraftsDB = GuildWorkshopDB
end

GuildieCraftsDB = GuildieCraftsDB or {
    orders = {},
    rooms = {},
    stock = { bags = {}, bank = {}, jcReports = {} },
    recipes = { jcReports = {} },
    settings = { jcMode = false, activeRoomId = nil, dataVersion = 0 },
}

local DATA_VERSION = 1

local function MigrateSavedData()
    GuildieCraftsDB.settings = GuildieCraftsDB.settings or {}
    if (GuildieCraftsDB.settings.dataVersion or 0) < DATA_VERSION then
        GuildieCraftsDB.orders = {}
        GuildieCraftsDB.rooms = {}
        GuildieCraftsDB.stock = { bags = {}, bank = {}, jcReports = {} }
        GuildieCraftsDB.recipes = { jcReports = {} }
        GuildieCraftsDB.settings.activeRoomId = nil
        GuildieCraftsDB.settings.dataVersion = DATA_VERSION
    end
end

local STATUS_LABELS = {
    pending = "|cffffcc00Pending|r",
    in_progress = "|cff66ccffIn Progress|r",
    completed = "|cff00ff00Completed|r",
    cancelled = "|cff888888Cancelled|r",
}

function GuildieCrafts_GetStatusLabel(status)
    return STATUS_LABELS[status] or status
end

function GuildieCrafts_GetOrderStatusLabel(order)
    if not order then
        return ""
    end
    if order.status == "in_progress" then
        local assignee = order.assignedTo or order.updatedBy
        if assignee then
            return string.format(
                "|cff66ccffIn progress - by %s|r",
                GuildieCrafts_ColorizePlayer(assignee)
            )
        end
    elseif order.status == "completed" then
        local completer = order.updatedBy or order.assignedTo
        if completer then
            return string.format(
                "|cff00ff00Completed - by %s|r",
                GuildieCrafts_ColorizePlayer(completer)
            )
        end
        return "|cff00ff00Completed|r"
    end
    return GuildieCrafts_GetStatusLabel(order.status)
end

function GuildieCrafts_GetSeenOrderIds()
    GuildieCraftsDB.settings = GuildieCraftsDB.settings or {}
    GuildieCraftsDB.settings.seenOrderIds = GuildieCraftsDB.settings.seenOrderIds or {}
    return GuildieCraftsDB.settings.seenOrderIds
end

function GuildieCrafts_IsOrderNewToViewer(order)
    if not order or not order.id or order.status ~= "pending" then
        return false
    end
    return GuildieCrafts_GetSeenOrderIds()[order.id] ~= true
end

function GuildieCrafts_GetPendingOrderBandLabel(order)
    if GuildieCrafts_IsOrderNewToViewer(order) then
        return "|cffFFAA00New|r"
    end
    return GuildieCrafts_GetStatusLabel("pending")
end

function GuildieCrafts_MarkPendingOrdersSeen()
    local seen = GuildieCrafts_GetSeenOrderIds()
    for _, order in ipairs(GuildieCrafts_GetActiveOrders()) do
        if order.status == "pending" and order.id then
            seen[order.id] = true
        end
    end
end

function GuildieCrafts_MarkOrderSeen(orderId)
    if not orderId then
        return
    end
    GuildieCrafts_GetSeenOrderIds()[orderId] = true
end

GuildieCrafts.VERSION = "2.2.6"

function GuildieCrafts_GetVersion()
    return GuildieCrafts.VERSION
end

function GuildieCrafts_RefreshUI()
    if GuildieCrafts.UI and GuildieCrafts.UI.frame then
        GuildieCrafts.UI:Refresh()
    end
end

function GuildieCrafts_EnsureUI()
    if GuildieCrafts.UI and GuildieCrafts.UI.frame then
        return true
    end

    if not GuildieCrafts.UI or not GuildieCrafts.UI.Init then
        print("|cffff0000Guildie Crafts|r UI failed to load.")
        return false
    end

    local ok, err = pcall(function()
        GuildieCrafts_HookDropdownMenuTooltips()
        GuildieCrafts.UI:Init()
    end)
    if not ok then
        print("|cffff0000Guildie Crafts UI error:|r " .. tostring(err))
        return false
    end
    return GuildieCrafts.UI and GuildieCrafts.UI.frame ~= nil
end

GuildieCrafts_ROLES = { "Tank", "Healer", "DPS" }

local ROLE_COLORS = {
    Tank = "0070dd",
    Healer = "1eff00",
    DPS = "ff2020",
}

local ROLE_DISPLAY_COLOR = "ffff00"

function GuildieCrafts_GetRoleLabel(role)
    role = role or "DPS"
    return string.format("|cff%s%s|r", ROLE_DISPLAY_COLOR, role)
end

local function NormalizePlayerName(name)
    if Ambiguate then
        return Ambiguate(name, "none")
    end
    return name
end

local function LocalizedClassToToken(classDisplayName)
    if not classDisplayName or classDisplayName == "" then
        return nil
    end
    if RAID_CLASS_COLORS[classDisplayName] then
        return classDisplayName
    end
    if LOCALIZED_CLASS_NAMES_MALE then
        for token, localized in pairs(LOCALIZED_CLASS_NAMES_MALE) do
            if localized == classDisplayName then
                return token
            end
        end
    end
    if LOCALIZED_CLASS_NAMES_FEMALE then
        for token, localized in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
            if localized == classDisplayName then
                return token
            end
        end
    end
    return nil
end

local function ClassFromGuildRosterInfo(name, classDisplayName, classFileName)
    if classFileName and classFileName ~= "" then
        return classFileName
    end
    return LocalizedClassToToken(classDisplayName)
end

function GuildieCrafts_GetPlayerClassToken(playerName)
    if not playerName then
        return nil
    end
    local normalized = NormalizePlayerName(playerName)
    GuildieCraftsDB = GuildieCraftsDB or {}
    GuildieCraftsDB.playerClasses = GuildieCraftsDB.playerClasses or {}
    if GuildieCraftsDB.playerClasses[normalized] then
        return GuildieCraftsDB.playerClasses[normalized]
    end

    if normalized == NormalizePlayerName(UnitName("player")) then
        local _, class = UnitClass("player")
        if class then
            GuildieCraftsDB.playerClasses[normalized] = class
        end
        return class
    end

    local function classFromUnit(unit)
        if UnitExists(unit) and NormalizePlayerName(UnitName(unit)) == normalized then
            local _, class = UnitClass(unit)
            return class
        end
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local class = classFromUnit("raid" .. i)
            if class then
                GuildieCraftsDB.playerClasses[normalized] = class
                return class
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local class = classFromUnit("party" .. i)
            if class then
                GuildieCraftsDB.playerClasses[normalized] = class
                return class
            end
        end
    end

    if IsInGuild() then
        for i = 1, GetNumGuildMembers() do
            local name, _, _, _, classDisplayName, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
            if name and NormalizePlayerName(name) == normalized then
                local class = ClassFromGuildRosterInfo(name, classDisplayName, classFileName)
                if class then
                    GuildieCraftsDB.playerClasses[normalized] = class
                end
                return class
            end
        end
    end

    return nil
end

function GuildieCrafts_GetClassColor(classToken)
    if not classToken or not RAID_CLASS_COLORS or not RAID_CLASS_COLORS[classToken] then
        return "ffffff"
    end

    local classColor = RAID_CLASS_COLORS[classToken]
    local colorStr = classColor.colorStr
    if type(colorStr) == "string" then
        colorStr = colorStr:lower()
        if #colorStr == 8 then
            return colorStr:sub(3, 8)
        end
        if #colorStr == 6 then
            return colorStr
        end
    end

    if classColor.r and classColor.g and classColor.b then
        return string.format("%02x%02x%02x", classColor.r * 255, classColor.g * 255, classColor.b * 255)
    end

    return "ffffff"
end

function GuildieCrafts_ColorizePlayer(name, classToken)
    classToken = classToken or GuildieCrafts_GetPlayerClassToken(name)
    local color = GuildieCrafts_GetClassColor(classToken)
    return string.format("|cff%s%s|r", color, name or "")
end

function GuildieCrafts_IsValidRole(role)
    for _, valid in ipairs(GuildieCrafts_ROLES) do
        if valid == role then
            return true
        end
    end
    return false
end

function GuildieCrafts_CreateOrder(gear, gems, notes, role)
    local player = UnitName("player")
    if not player then
        return nil, "Not logged in."
    end
    if not IsInGuild() then
        return nil, "You must be in a guild to place orders."
    end

    local roomId = GuildieCrafts_GetActiveRoomId()
    local room = GuildieCrafts_GetActiveRoom()
    if not roomId or not room then
        return nil, "Select a workshop before placing an order."
    end
    if not GuildieCrafts_IsRoomMember(room, player) then
        return nil, "Select the active workshop before placing an order."
    end

    if not gear or type(gear) ~= "table" or not gear.name or not gear.itemId then
        return nil, "Select gear from the list."
    end
    if not GuildieCrafts_GetGearByName(gear.name) then
        return nil, "Select a valid gear item."
    end

    local filteredGems = {}
    for _, gem in ipairs(gems or {}) do
        if gem and gem ~= "" and gem ~= "None" then
            table.insert(filteredGems, gem)
        end
    end
    if #filteredGems == 0 then
        return nil, "Select at least one gem."
    end

    role = role or ""
    if not GuildieCrafts_IsValidRole(role) then
        return nil, "Select a role."
    end

    local _, classToken = UnitClass("player")
    local order = {
        id = GuildieCrafts.Sync:GenerateOrderId(),
        player = player,
        class = classToken,
        item = gear.name,
        itemLink = "item:" .. gear.itemId,
        itemId = gear.itemId,
        gems = filteredGems,
        notes = notes,
        role = role,
        status = "pending",
        created = time(),
        roomId = roomId,
    }

    GuildieCraftsDB.orders[order.id] = order
    GuildieCrafts_AppendOrderToQueue(roomId, order.id)
    GuildieCrafts.Sync:BroadcastOrder(order)
    return order
end

function GuildieCrafts_GetCraftCategoryLabel(category)
    if not category or category == "" then
        return ""
    end
    return string.format("|cff%s%s|r", ROLE_DISPLAY_COLOR, category)
end

function GuildieCrafts_GetOrderHeaderTag(order)
    if not order then
        return ""
    end
    local isCraft = order.orderKind == "craft"
    if not isCraft and (not order.gems or #order.gems == 0) then
        isCraft = GuildieCrafts_GetCraftByItemId(order.itemId) ~= nil
            or GuildieCrafts_GetCraftByName(order.item) ~= nil
    end
    if isCraft then
        if order.role and GuildieCrafts_IsValidRole(order.role) then
            return GuildieCrafts_GetRoleLabel(order.role)
        end
        if order.craftCategory and order.craftCategory ~= "" then
            return GuildieCrafts_GetCraftCategoryLabel(order.craftCategory)
        end
        local craft = GuildieCrafts_GetCraftByItemId(order.itemId)
            or GuildieCrafts_GetCraftByName(order.item)
        if craft and craft.category then
            return GuildieCrafts_GetCraftCategoryLabel(craft.category)
        end
        return ""
    end
    return GuildieCrafts_GetRoleLabel(order.role)
end

function GuildieCrafts_CreateCraftOrder(craft, notes, role)
    local player = UnitName("player")
    if not player then
        return nil, "Not logged in."
    end
    if not IsInGuild() then
        return nil, "You must be in a guild to place orders."
    end

    local roomId = GuildieCrafts_GetActiveRoomId()
    local room = GuildieCrafts_GetActiveRoom()
    if not roomId or not room then
        return nil, "Select a workshop before placing an order."
    end
    if not GuildieCrafts_IsRoomMember(room, player) then
        return nil, "Select the active workshop before placing an order."
    end
    if not GuildieCrafts_IsHoDProfession(GuildieCrafts_GetRoomProfession(room)) then
        return nil, "This workshop does not accept craft orders."
    end

    if type(craft) ~= "table" or not craft.name or not craft.itemId then
        return nil, "Select a craft from the list."
    end
    if not GuildieCrafts_GetCraftByName(craft.name) then
        return nil, "Select a valid craft."
    end

    role = role or ""
    if not GuildieCrafts_IsValidRole(role) then
        return nil, "Select a role."
    end

    local _, classToken = UnitClass("player")
    local materialName = GuildieCrafts_GetRoomScarceMaterialName(room) or "Heart of Darkness"
    local scarceMaterial = GuildieCrafts_GetRoomScarceMaterial(room)
    local order = {
        id = GuildieCrafts.Sync:GenerateOrderId(),
        player = player,
        class = classToken,
        orderKind = "craft",
        item = craft.name,
        itemLink = "item:" .. craft.itemId,
        itemId = craft.itemId,
        gems = {},
        material = materialName,
        materialItemId = scarceMaterial and scarceMaterial.itemId or nil,
        materialCount = craft.hodCost or 1,
        notes = notes,
        role = role,
        craftCategory = craft.category,
        status = "pending",
        created = time(),
        roomId = roomId,
    }

    GuildieCraftsDB.orders[order.id] = order
    GuildieCrafts_AppendOrderToQueue(roomId, order.id)
    GuildieCrafts.Sync:BroadcastOrder(order)
    return order
end

function GuildieCrafts_UpdateStatus(orderId, status)
    local order = GuildieCraftsDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    order.status = status
    order.updatedBy = UnitName("player")
    order.updatedAt = time()
    if status == "in_progress" then
        order.assignedTo = UnitName("player")
    end
    GuildieCrafts.Sync:BroadcastStatus(orderId, status, order.updatedBy, order.assignedTo)
    return true
end

function GuildieCrafts_CancelOrder(orderId)
    local order = GuildieCraftsDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    local player = UnitName("player")
    if order.player ~= player and not GuildieCrafts_CanManageOrder(order) then
        return false, "You can only cancel your own orders."
    end

    order.status = "cancelled"
    GuildieCrafts_RemoveOrderFromQueue(order.roomId, orderId)
    GuildieCrafts.Sync:BroadcastStatus(orderId, "cancelled", player)
    return true
end

function GuildieCrafts_DeleteOrder(orderId)
    local order = GuildieCraftsDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    local room = order.roomId and GuildieCrafts_GetRoom(order.roomId)
    if not GuildieCrafts_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can delete orders."
    end

    GuildieCrafts_RemoveOrderFromQueue(order.roomId, orderId)
    GuildieCraftsDB.orders[orderId] = nil
    GuildieCrafts.Sync:BroadcastRemove(orderId)
    if order.roomId and room then
        GuildieCrafts.Sync:BroadcastOrderQueue(order.roomId, GuildieCrafts_GetRoomOrderQueue(room))
    end
    return true
end

function GuildieCrafts_GetRoomOrderQueue(room)
    if not room then
        return {}
    end
    room.orderQueue = room.orderQueue or {}
    return room.orderQueue
end

function GuildieCrafts_AppendOrderToQueue(roomId, orderId)
    local room = GuildieCrafts_GetRoom(roomId)
    if not room or not orderId then
        return
    end
    local queue = GuildieCrafts_GetRoomOrderQueue(room)
    for _, id in ipairs(queue) do
        if id == orderId then
            return
        end
    end
    table.insert(queue, orderId)
end

function GuildieCrafts_RemoveOrderFromQueue(roomId, orderId)
    local room = GuildieCrafts_GetRoom(roomId)
    if not room or not orderId then
        return
    end
    local queue = GuildieCrafts_GetRoomOrderQueue(room)
    for i, id in ipairs(queue) do
        if id == orderId then
            table.remove(queue, i)
            break
        end
    end
end

function GuildieCrafts_SyncQueueWithOrders(room)
    if not room then
        return
    end
    local queue = GuildieCrafts_GetRoomOrderQueue(room)
    local known = {}
    for _, id in ipairs(queue) do
        known[id] = true
    end

    local toAdd = {}
    for _, order in pairs(GuildieCraftsDB.orders or {}) do
        if order.roomId == room.id and order.status ~= "cancelled" and order.status ~= "completed" then
            if not known[order.id] then
                table.insert(toAdd, order.id)
            end
        end
    end
    table.sort(toAdd, function(a, b)
        return (GuildieCraftsDB.orders[a].created or 0) < (GuildieCraftsDB.orders[b].created or 0)
    end)
    for _, id in ipairs(toAdd) do
        table.insert(queue, id)
    end

    local cleaned = {}
    for _, id in ipairs(queue) do
        local order = GuildieCraftsDB.orders[id]
        if order and order.roomId == room.id and order.status ~= "cancelled" then
            table.insert(cleaned, id)
        end
    end
    room.orderQueue = cleaned
end

local function GetQueueIndex(room, orderId)
    if not room or not room.orderQueue then
        return nil
    end
    for i, id in ipairs(room.orderQueue) do
        if id == orderId then
            return i
        end
    end
    return nil
end

function GuildieCrafts_MoveOrder(orderId, direction)
    local room = GuildieCrafts_GetActiveRoom()
    if not room then
        return false, "Select a workshop first."
    end
    if not GuildieCrafts_IsWorkshopJC(room, UnitName("player")) then
        local crafters = string.lower(GuildieCrafts_GetCrafterLabel(GuildieCrafts_GetRoomProfession(room)))
        return false, "Only promoted " .. crafters .. " can reorder the queue."
    end

    GuildieCrafts_SyncQueueWithOrders(room)
    local queue = room.orderQueue
    local index
    for i, id in ipairs(queue) do
        if id == orderId then
            index = i
            break
        end
    end
    if not index then
        return false, "Order not in queue."
    end

    local order = GuildieCraftsDB.orders[orderId]
    if not order or order.status == "completed" or order.status == "cancelled" then
        return false, "Cannot reorder that order."
    end

    local newIndex = index + direction
    if newIndex < 1 or newIndex > #queue then
        return false, "Already at the edge of the queue."
    end

    local otherId = queue[newIndex]
    local otherOrder = GuildieCraftsDB.orders[otherId]
    if not otherOrder or otherOrder.status == "completed" or otherOrder.status == "cancelled" then
        return false, "Cannot swap with that order."
    end

    queue[index], queue[newIndex] = queue[newIndex], queue[index]
    GuildieCrafts.Sync:BroadcastOrderQueue(room.id, queue)
    return true
end

local function CollectSortedOrders(mode)
    if not GuildieCrafts_HasJoinedWorkshop() then
        return {}
    end
    local room = GuildieCrafts_GetActiveRoom()
    if room then
        GuildieCrafts_SyncQueueWithOrders(room)
    end

    local list = {}
    local activeRoomId = GuildieCrafts_GetActiveRoomId()
    for _, order in pairs(GuildieCraftsDB.orders or {}) do
        if order.status ~= "cancelled" then
            if not activeRoomId or order.roomId == activeRoomId then
                if mode == "active" and order.status == "completed" then
                    -- skip
                elseif mode == "completed" and order.status ~= "completed" then
                    -- skip
                else
                    table.insert(list, order)
                end
            end
        end
    end

    if mode == "completed" then
        table.sort(list, function(a, b)
            return (a.created or 0) > (b.created or 0)
        end)
        return list
    end

    local rank = { pending = 1, in_progress = 2 }
    table.sort(list, function(a, b)
        local ra = rank[a.status] or 9
        local rb = rank[b.status] or 9
        if ra ~= rb then
            return ra < rb
        end
        if room then
            local ia = GetQueueIndex(room, a.id) or 9999
            local ib = GetQueueIndex(room, b.id) or 9999
            if ia ~= ib then
                return ia < ib
            end
        end
        return (a.created or 0) < (b.created or 0)
    end)
    return list
end

function GuildieCrafts_GetSortedOrders()
    return CollectSortedOrders("active")
end

function GuildieCrafts_GetActiveOrders()
    return CollectSortedOrders("active")
end

function GuildieCrafts_GetCompletedOrders()
    return CollectSortedOrders("completed")
end

local function After(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
        return
    end
    local timer = CreateFrame("Frame")
    local elapsed = 0
    timer:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            fn()
        end
    end)
end

local function OnAddonLoaded(_, addon)
    if addon ~= ADDON_NAME then
        return
    end

    MigrateSavedData()

    local ok, err = pcall(function()
        GuildieCrafts.Sync:Init()
        GuildieCrafts_TooltipsInit()
        if GuildieCrafts_InitStockEvents then
            GuildieCrafts_InitStockEvents()
        end
        GuildieCrafts.Minimap:Init()
    end)
    if not ok then
        print("|cffff0000Guildie Crafts minimap/sync error:|r " .. tostring(err))
    end

    if GuildieCrafts.Minimap.button then
        print("|cff00ccffGuildie Crafts|r loaded. Click the icon on your minimap, or type |cff00ccff/gc|r.")
    else
        print("|cffff0000Guildie Crafts failed to load.|r Check chat for errors.")
    end
end

local function TryGuildSync()
    if not IsInGuild() or not GuildieCrafts_GetGuildName() then
        return false
    end

    if GuildRoster then
        GuildRoster()
    end

    GuildieCrafts_PurgeNonGuildData()
    GuildieCrafts.Sync:BroadcastAllRooms()
    GuildieCrafts.Sync:RequestSync()

    if GuildieCrafts_HasJoinedWorkshop() then
        GuildieCrafts_ScanBagsForGems()
        GuildieCrafts_ScanPersonalBankForGems()
        if GuildieCrafts_ShouldShareStock() then
            GuildieCrafts_ShareWorkshopStock()
        end
    end

    if GuildieCrafts.UI and GuildieCrafts.UI.frame then
        GuildieCrafts.UI:Refresh()
    end

    if GuildieCrafts_ScheduleMissedNotificationCheck then
        GuildieCrafts_ScheduleMissedNotificationCheck(3)
    end

    return true
end

local function OnPlayerLogin()
    if not GuildieCrafts.Minimap.button then
        pcall(function() GuildieCrafts.Minimap:Init() end)
    end

    After(1, function()
        TryGuildSync()
    end)
    After(5, function()
        TryGuildSync()
    end)
end

local function OnGuildReady()
    TryGuildSync()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("GUILD_ROSTER_UPDATE")
boot:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(event, arg1)
    elseif event == "PLAYER_LOGIN" then
        OnPlayerLogin()
    elseif event == "GUILD_ROSTER_UPDATE" then
        OnGuildReady()
        if GuildieCrafts.UI and GuildieCrafts.UI.frame then
            GuildieCrafts.UI:Refresh()
        end
    end
end)
