local ADDON_NAME = ...

if not strtrim then
    function strtrim(s)
        return (s:gsub("^%s*(.-)%s*$", "%1"))
    end
end

GuildWorkshop = GuildWorkshop or {}
GuildWorkshop.UI = GuildWorkshop.UI or {}
GuildWorkshopDB = GuildWorkshopDB or {
    orders = {},
    rooms = {},
    stock = { bags = {}, bank = {}, jcReports = {} },
    recipes = { jcReports = {} },
    settings = { jcMode = false, activeRoomId = nil, dataVersion = 0 },
}

local DATA_VERSION = 1

local function MigrateSavedData()
    GuildWorkshopDB.settings = GuildWorkshopDB.settings or {}
    if (GuildWorkshopDB.settings.dataVersion or 0) < DATA_VERSION then
        GuildWorkshopDB.orders = {}
        GuildWorkshopDB.rooms = {}
        GuildWorkshopDB.stock = { bags = {}, bank = {}, jcReports = {} }
        GuildWorkshopDB.recipes = { jcReports = {} }
        GuildWorkshopDB.settings.activeRoomId = nil
        GuildWorkshopDB.settings.dataVersion = DATA_VERSION
    end
end

local STATUS_LABELS = {
    pending = "|cffffcc00Pending|r",
    in_progress = "|cff66ccffIn Progress|r",
    completed = "|cff00ff00Completed|r",
    cancelled = "|cff888888Cancelled|r",
}

function GuildWorkshop_GetStatusLabel(status)
    return STATUS_LABELS[status] or status
end

function GuildWorkshop_GetOrderStatusLabel(order)
    if not order then
        return ""
    end
    if order.status == "in_progress" then
        local assignee = order.assignedTo or order.updatedBy
        if assignee then
            return string.format(
                "|cff66ccffIn progress - by %s|r",
                GuildWorkshop_ColorizePlayer(assignee)
            )
        end
    end
    return GuildWorkshop_GetStatusLabel(order.status)
end

GuildWorkshop.VERSION = "1.2.6"

function GuildWorkshop_GetVersion()
    return GuildWorkshop.VERSION
end

function GuildWorkshop_RefreshUI()
    if GuildWorkshop.UI and GuildWorkshop.UI.frame then
        GuildWorkshop.UI:Refresh()
    end
end

function GuildWorkshop_EnsureUI()
    if GuildWorkshop.UI and GuildWorkshop.UI.frame then
        return true
    end

    if not GuildWorkshop.UI or not GuildWorkshop.UI.Init then
        print("|cffff0000Guild Workshop|r UI failed to load.")
        return false
    end

    local ok, err = pcall(function()
        GuildWorkshop_HookDropdownMenuTooltips()
        GuildWorkshop.UI:Init()
    end)
    if not ok then
        print("|cffff0000GuildWorkshop UI error:|r " .. tostring(err))
        return false
    end
    return GuildWorkshop.UI and GuildWorkshop.UI.frame ~= nil
end

GuildWorkshop_ROLES = { "Tank", "Healer", "DPS" }

local ROLE_COLORS = {
    Tank = "0070dd",
    Healer = "1eff00",
    DPS = "ff2020",
}

local ROLE_DISPLAY_COLOR = "ffff00"

function GuildWorkshop_GetRoleLabel(role)
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

function GuildWorkshop_GetPlayerClassToken(playerName)
    if not playerName then
        return nil
    end
    local normalized = NormalizePlayerName(playerName)
    GuildWorkshopDB = GuildWorkshopDB or {}
    GuildWorkshopDB.playerClasses = GuildWorkshopDB.playerClasses or {}
    if GuildWorkshopDB.playerClasses[normalized] then
        return GuildWorkshopDB.playerClasses[normalized]
    end

    if normalized == NormalizePlayerName(UnitName("player")) then
        local _, class = UnitClass("player")
        if class then
            GuildWorkshopDB.playerClasses[normalized] = class
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
                GuildWorkshopDB.playerClasses[normalized] = class
                return class
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() - 1 do
            local class = classFromUnit("party" .. i)
            if class then
                GuildWorkshopDB.playerClasses[normalized] = class
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
                    GuildWorkshopDB.playerClasses[normalized] = class
                end
                return class
            end
        end
    end

    return nil
end

function GuildWorkshop_GetClassColor(classToken)
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

function GuildWorkshop_ColorizePlayer(name, classToken)
    classToken = classToken or GuildWorkshop_GetPlayerClassToken(name)
    local color = GuildWorkshop_GetClassColor(classToken)
    return string.format("|cff%s%s|r", color, name or "")
end

function GuildWorkshop_IsValidRole(role)
    for _, valid in ipairs(GuildWorkshop_ROLES) do
        if valid == role then
            return true
        end
    end
    return false
end

function GuildWorkshop_CreateOrder(gear, gems, notes, role)
    local player = UnitName("player")
    if not player then
        return nil, "Not logged in."
    end
    if not IsInGuild() then
        return nil, "You must be in a guild to place orders."
    end

    local roomId = GuildWorkshop_GetActiveRoomId()
    local room = GuildWorkshop_GetActiveRoom()
    if not roomId or not room then
        return nil, "Select a workshop before placing an order."
    end
    if not GuildWorkshop_IsRoomMember(room, player) then
        return nil, "Select the active workshop before placing an order."
    end

    if not gear or type(gear) ~= "table" or not gear.name or not gear.itemId then
        return nil, "Select gear from the list."
    end
    if not GuildWorkshop_GetGearByName(gear.name) then
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
    if not GuildWorkshop_IsValidRole(role) then
        return nil, "Select a role."
    end

    local _, classToken = UnitClass("player")
    local order = {
        id = GuildWorkshop.Sync:GenerateOrderId(),
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

    GuildWorkshopDB.orders[order.id] = order
    GuildWorkshop_AppendOrderToQueue(roomId, order.id)
    GuildWorkshop.Sync:BroadcastOrder(order)
    return order
end

function GuildWorkshop_CreateCraftOrder(craft, notes, role)
    local player = UnitName("player")
    if not player then
        return nil, "Not logged in."
    end
    if not IsInGuild() then
        return nil, "You must be in a guild to place orders."
    end

    local roomId = GuildWorkshop_GetActiveRoomId()
    local room = GuildWorkshop_GetActiveRoom()
    if not roomId or not room then
        return nil, "Select a workshop before placing an order."
    end
    if not GuildWorkshop_IsRoomMember(room, player) then
        return nil, "Select the active workshop before placing an order."
    end
    if not GuildWorkshop_IsHoDProfession(GuildWorkshop_GetRoomProfession(room)) then
        return nil, "This workshop does not accept craft orders."
    end

    if type(craft) ~= "table" or not craft.name or not craft.itemId then
        return nil, "Select a craft from the list."
    end
    if not GuildWorkshop_GetCraftByName(craft.name) then
        return nil, "Select a valid craft."
    end

    role = role or ""
    if not GuildWorkshop_IsValidRole(role) then
        return nil, "Select a role."
    end

    local _, classToken = UnitClass("player")
    local materialName = GuildWorkshop_GetRoomScarceMaterialName(room) or "Heart of Darkness"
    local order = {
        id = GuildWorkshop.Sync:GenerateOrderId(),
        player = player,
        class = classToken,
        orderKind = "craft",
        item = craft.name,
        itemLink = "item:" .. craft.itemId,
        itemId = craft.itemId,
        gems = {},
        material = materialName,
        materialCount = craft.hodCost or 1,
        notes = notes,
        role = role,
        status = "pending",
        created = time(),
        roomId = roomId,
    }

    GuildWorkshopDB.orders[order.id] = order
    GuildWorkshop_AppendOrderToQueue(roomId, order.id)
    GuildWorkshop.Sync:BroadcastOrder(order)
    return order
end

function GuildWorkshop_UpdateStatus(orderId, status)
    local order = GuildWorkshopDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    order.status = status
    order.updatedBy = UnitName("player")
    order.updatedAt = time()
    if status == "in_progress" then
        order.assignedTo = UnitName("player")
    end
    GuildWorkshop.Sync:BroadcastStatus(orderId, status, order.updatedBy, order.assignedTo)
    return true
end

function GuildWorkshop_CancelOrder(orderId)
    local order = GuildWorkshopDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    local player = UnitName("player")
    if order.player ~= player and not GuildWorkshop_CanManageOrder(order) then
        return false, "You can only cancel your own orders."
    end

    order.status = "cancelled"
    GuildWorkshop_RemoveOrderFromQueue(order.roomId, orderId)
    GuildWorkshop.Sync:BroadcastStatus(orderId, "cancelled", player)
    return true
end

function GuildWorkshop_DeleteOrder(orderId)
    local order = GuildWorkshopDB.orders[orderId]
    if not order then
        return false, "Order not found."
    end

    local room = order.roomId and GuildWorkshop_GetRoom(order.roomId)
    if not GuildWorkshop_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can delete orders."
    end

    GuildWorkshop_RemoveOrderFromQueue(order.roomId, orderId)
    GuildWorkshopDB.orders[orderId] = nil
    GuildWorkshop.Sync:BroadcastRemove(orderId)
    if order.roomId and room then
        GuildWorkshop.Sync:BroadcastOrderQueue(order.roomId, GuildWorkshop_GetRoomOrderQueue(room))
    end
    return true
end

function GuildWorkshop_GetRoomOrderQueue(room)
    if not room then
        return {}
    end
    room.orderQueue = room.orderQueue or {}
    return room.orderQueue
end

function GuildWorkshop_AppendOrderToQueue(roomId, orderId)
    local room = GuildWorkshop_GetRoom(roomId)
    if not room or not orderId then
        return
    end
    local queue = GuildWorkshop_GetRoomOrderQueue(room)
    for _, id in ipairs(queue) do
        if id == orderId then
            return
        end
    end
    table.insert(queue, orderId)
end

function GuildWorkshop_RemoveOrderFromQueue(roomId, orderId)
    local room = GuildWorkshop_GetRoom(roomId)
    if not room or not orderId then
        return
    end
    local queue = GuildWorkshop_GetRoomOrderQueue(room)
    for i, id in ipairs(queue) do
        if id == orderId then
            table.remove(queue, i)
            break
        end
    end
end

function GuildWorkshop_SyncQueueWithOrders(room)
    if not room then
        return
    end
    local queue = GuildWorkshop_GetRoomOrderQueue(room)
    local known = {}
    for _, id in ipairs(queue) do
        known[id] = true
    end

    local toAdd = {}
    for _, order in pairs(GuildWorkshopDB.orders or {}) do
        if order.roomId == room.id and order.status ~= "cancelled" and order.status ~= "completed" then
            if not known[order.id] then
                table.insert(toAdd, order.id)
            end
        end
    end
    table.sort(toAdd, function(a, b)
        return (GuildWorkshopDB.orders[a].created or 0) < (GuildWorkshopDB.orders[b].created or 0)
    end)
    for _, id in ipairs(toAdd) do
        table.insert(queue, id)
    end

    local cleaned = {}
    for _, id in ipairs(queue) do
        local order = GuildWorkshopDB.orders[id]
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

function GuildWorkshop_MoveOrder(orderId, direction)
    local room = GuildWorkshop_GetActiveRoom()
    if not room then
        return false, "Select a workshop first."
    end
    if not GuildWorkshop_IsWorkshopJC(room, UnitName("player")) then
        local crafters = string.lower(GuildWorkshop_GetCrafterLabel(GuildWorkshop_GetRoomProfession(room)))
        return false, "Only promoted " .. crafters .. " can reorder the queue."
    end

    GuildWorkshop_SyncQueueWithOrders(room)
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

    local order = GuildWorkshopDB.orders[orderId]
    if not order or order.status == "completed" or order.status == "cancelled" then
        return false, "Cannot reorder that order."
    end

    local newIndex = index + direction
    if newIndex < 1 or newIndex > #queue then
        return false, "Already at the edge of the queue."
    end

    local otherId = queue[newIndex]
    local otherOrder = GuildWorkshopDB.orders[otherId]
    if not otherOrder or otherOrder.status == "completed" or otherOrder.status == "cancelled" then
        return false, "Cannot swap with that order."
    end

    queue[index], queue[newIndex] = queue[newIndex], queue[index]
    GuildWorkshop.Sync:BroadcastOrderQueue(room.id, queue)
    return true
end

local function CollectSortedOrders(mode)
    if not GuildWorkshop_HasJoinedWorkshop() then
        return {}
    end
    local room = GuildWorkshop_GetActiveRoom()
    if room then
        GuildWorkshop_SyncQueueWithOrders(room)
    end

    local list = {}
    local activeRoomId = GuildWorkshop_GetActiveRoomId()
    for _, order in pairs(GuildWorkshopDB.orders or {}) do
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

function GuildWorkshop_GetSortedOrders()
    return CollectSortedOrders("active")
end

function GuildWorkshop_GetActiveOrders()
    return CollectSortedOrders("active")
end

function GuildWorkshop_GetCompletedOrders()
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
        GuildWorkshop.Sync:Init()
        GuildWorkshop_TooltipsInit()
        if GuildWorkshop_InitStockEvents then
            GuildWorkshop_InitStockEvents()
        end
        GuildWorkshop.Minimap:Init()
    end)
    if not ok then
        print("|cffff0000GuildWorkshop minimap/sync error:|r " .. tostring(err))
    end

    if GuildWorkshop.Minimap.button then
        print("|cff00ccffGuild Workshop|r loaded. Click the gem icon on your minimap, or type |cff00ccff/GuildWorkshop|r.")
    else
        print("|cffff0000GuildWorkshop failed to load.|r Check chat for errors.")
    end
end

local function TryGuildSync()
    if not IsInGuild() or not GuildWorkshop_GetGuildName() then
        return false
    end

    if GuildRoster then
        GuildRoster()
    end

    GuildWorkshop_PurgeNonGuildData()
    GuildWorkshop.Sync:BroadcastAllRooms()
    GuildWorkshop.Sync:RequestSync()

    if GuildWorkshop_HasJoinedWorkshop() then
        GuildWorkshop_ScanBagsForGems()
        GuildWorkshop_ScanPersonalBankForGems()
        if GuildWorkshop_ShouldShareStock() then
            GuildWorkshop_ShareWorkshopStock()
        end
    end

    if GuildWorkshop.UI and GuildWorkshop.UI.frame then
        GuildWorkshop.UI:Refresh()
    end

    return true
end

local function OnPlayerLogin()
    if not GuildWorkshop.Minimap.button then
        pcall(function() GuildWorkshop.Minimap:Init() end)
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
        if GuildWorkshop.UI and GuildWorkshop.UI.frame then
            GuildWorkshop.UI:Refresh()
        end
    end
end)
