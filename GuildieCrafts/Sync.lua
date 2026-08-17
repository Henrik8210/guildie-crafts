local ADDON_NAME = ...

GuildieCrafts = GuildieCrafts or {}
local Sync = {}
GuildieCrafts.Sync = Sync

local PREFIX = "GuildieCft"
local MSG_ADD = "A"
local MSG_STATUS = "S"
local MSG_REMOVE = "R"
local MSG_REQUEST = "Q"
local MSG_ROOM = "W"
local MSG_JOIN = "J"
local MSG_LEAVE = "L"
local MSG_COLLAB = "C"
local MSG_COLEADER = "O"
local MSG_STOCK = "K"
local MSG_QUEUE = "P"
local MSG_RECIPES = "E"

local function SplitMessage(msg, sep)
    local parts = {}
    for part in string.gmatch(msg, "([^" .. sep .. "]+)") do
        table.insert(parts, part)
    end
    return parts
end

local function JoinGems(gems)
    if not gems or #gems == 0 then
        return "-"
    end
    return table.concat(gems, ";")
end

local function ParseGems(text)
    if not text or text == "" or text == "-" then
        return {}
    end
    return SplitMessage(text, ";")
end

local function EscapeField(text)
    text = text or ""
    text = string.gsub(text, ":", " ")
    text = string.gsub(text, "|", " ")
    return text
end

local function EncodeField(text)
    text = EscapeField(text)
    if text == "" then
        return "-"
    end
    return text
end

local function DecodeField(text)
    if not text or text == "" or text == "-" then
        return nil
    end
    return text
end

function Sync:Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_ADDON" then
            self:OnAddonMessage(...)
        end
    end)
    self.frame = frame
end

function Sync:Send(msg)
    if not IsInGuild() then
        return false
    end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        C_ChatInfo.SendAddonMessage(PREFIX, msg, "GUILD")
    else
        SendAddonMessage(PREFIX, msg, "GUILD")
    end
    return true
end

function Sync:BroadcastOrder(order)
    local msg = table.concat({
        MSG_ADD,
        order.id,
        EncodeField(order.player),
        EncodeField(order.item),
        JoinGems(order.gems),
        EncodeField(order.notes),
        order.status or "pending",
        tostring(order.created or time()),
        tostring(order.itemId or 0),
        EncodeField(order.roomId),
        EncodeField(order.role or "DPS"),
        EncodeField(order.class),
        EncodeField(order.assignedTo),
    }, ":")
    self:Send(msg)
end

function Sync:BroadcastRoomOrders(roomId)
    if not roomId then
        return
    end
    for _, order in pairs(GuildieCraftsDB.orders or {}) do
        if order.roomId == roomId then
            self:BroadcastOrder(order)
        end
    end
end

function Sync:BroadcastStatus(orderId, status, updatedBy, assignedTo)
    local msg = table.concat({
        MSG_STATUS,
        orderId,
        status,
        EscapeField(updatedBy or UnitName("player")),
        tostring(time()),
        EscapeField(assignedTo or ""),
    }, ":")
    self:Send(msg)
end

function Sync:BroadcastOrderQueue(roomId, queue)
    local ids = table.concat(queue or {}, ";")
    if ids == "" then
        ids = "-"
    end
    self:Send(table.concat({ MSG_QUEUE, roomId, ids }, ":"))
end

function Sync:BroadcastAllOrderQueues(requester)
    for _, room in pairs(GuildieCraftsDB.rooms or {}) do
        if room.id and room.orderQueue and GuildieCrafts_IsRoomMember(room, requester) then
            self:BroadcastOrderQueue(room.id, room.orderQueue)
        end
    end
end

function Sync:BroadcastRemove(orderId)
    self:Send(MSG_REMOVE .. ":" .. orderId)
end

function Sync:RequestSync()
    self:Send(MSG_REQUEST .. ":" .. EscapeField(UnitName("player")))
end

function Sync:BroadcastAllOrders()
    for _, order in pairs(GuildieCraftsDB.orders or {}) do
        self:BroadcastOrder(order)
    end
end

local function JoinNames(nameMap)
    local names = {}
    for name in pairs(nameMap or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    if #names == 0 then
        return "-"
    end
    return table.concat(names, ";")
end

local function ParseNames(text)
    if not text or text == "" or text == "-" then
        return {}
    end
    local map = {}
    for name in string.gmatch(text, "([^;]+)") do
        map[name] = true
    end
    return map
end

local function MergeNameMaps(...)
    local merged = {}
    for i = 1, select("#", ...) do
        local nameMap = select(i, ...)
        for name in pairs(nameMap or {}) do
            merged[name] = true
        end
    end
    return merged
end

local function EncodeStock(counts)
    local parts = {}
    for itemId, count in pairs(counts or {}) do
        if count and count > 0 then
            table.insert(parts, tostring(itemId) .. "," .. tostring(count))
        end
    end
    table.sort(parts)
    if #parts == 0 then
        return "-"
    end
    return table.concat(parts, ";")
end

local function DecodeStock(text)
    local counts = {}
    if not text or text == "" or text == "-" then
        return counts
    end
    for pair in string.gmatch(text, "([^;]+)") do
        local itemId, count = pair:match("(%d+),(%d+)")
        if itemId then
            counts[tonumber(itemId)] = tonumber(count) or 0
        end
    end
    return counts
end

local function EncodeRecipeIds(itemIdSet)
    local parts = {}
    for itemId in pairs(itemIdSet or {}) do
        table.insert(parts, tostring(itemId))
    end
    table.sort(parts)
    if #parts == 0 then
        return "-"
    end
    return table.concat(parts, ";")
end

local function DecodeRecipeIds(text)
    local itemIds = {}
    if not text or text == "" or text == "-" then
        return itemIds
    end
    for id in string.gmatch(text, "([^;]+)") do
        local itemId = tonumber(id)
        if itemId and GuildieCrafts_IsTrackedRecipeItemId(itemId) then
            itemIds[itemId] = true
        end
    end
    return itemIds
end

function Sync:BroadcastRoom(room)
    if not room or not room.id then
        return
    end
    local msg = table.concat({
        MSG_ROOM,
        room.id,
        EscapeField(room.name),
        EscapeField(room.leader),
        room.open and "1" or "0",
        JoinNames(room.collaborators),
        tostring(room.created or time()),
        EncodeField(room.guild),
        JoinNames(room.members),
        JoinNames(room.coLeaders),
        EncodeField(room.expansion or GuildieCrafts_GetDefaultExpansion()),
        EncodeField(room.phase or GuildieCrafts_GetDefaultPhase()),
        EncodeField(room.profession or "jewelcrafting"),
    }, ":")
    self:Send(msg)
end

function Sync:BroadcastJoin(roomId, player)
    self:Send(table.concat({ MSG_JOIN, roomId, EscapeField(player) }, ":"))
end

function Sync:BroadcastLeave(roomId, player)
    self:Send(table.concat({ MSG_LEAVE, roomId, EscapeField(player) }, ":"))
end

function Sync:BroadcastCollaborator(roomId, action, player)
    self:Send(table.concat({ MSG_COLLAB, roomId, action, EscapeField(player) }, ":"))
end

function Sync:BroadcastCoLeader(roomId, action, player)
    self:Send(table.concat({ MSG_COLEADER, roomId, action, EscapeField(player) }, ":"))
end

function Sync:BroadcastStock(counts, source)
    local msg = table.concat({
        MSG_STOCK,
        EscapeField(UnitName("player")),
        source or "bags",
        EncodeStock(counts),
    }, ":")
    self:Send(msg)
end

function Sync:BroadcastRecipes(itemIdSet)
    local msg = table.concat({
        MSG_RECIPES,
        EscapeField(UnitName("player")),
        EncodeRecipeIds(itemIdSet),
    }, ":")
    self:Send(msg)
end

function Sync:BroadcastAllRooms()
    for _, room in pairs(GuildieCraftsDB.rooms or {}) do
        if room.open then
            self:BroadcastRoom(room)
        end
    end
end

function Sync:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX or channel ~= "GUILD" then
        return
    end
    if not IsInGuild() then
        return
    end
    if sender == UnitName("player") then
        return
    end

    local parts = SplitMessage(message, ":")
    local msgType = parts[1]

    if msgType == MSG_ADD then
        local itemId = tonumber(parts[9]) or 0
        local roomId = DecodeField(parts[10])
        local room = roomId and GuildieCrafts_GetRoom(roomId)
        if not room or not GuildieCrafts_IsSameGuild(room) then
            return
        end
        if not GuildieCrafts_IsRoomMember(room, UnitName("player")) then
            return
        end
        local order = {
            id = parts[2],
            player = parts[3],
            item = parts[4],
            gems = ParseGems(parts[5]),
            notes = DecodeField(parts[6]),
            status = parts[7] or "pending",
            created = tonumber(parts[8]) or time(),
            itemId = itemId > 0 and itemId or nil,
            roomId = roomId,
            role = DecodeField(parts[11]) or "DPS",
            class = DecodeField(parts[12]),
            assignedTo = DecodeField(parts[13]),
        }
        local existing = GuildieCraftsDB.orders[order.id]
        if existing then
            if not order.assignedTo and existing.assignedTo then
                order.assignedTo = existing.assignedTo
            end
            if existing.updatedBy then
                order.updatedBy = existing.updatedBy
            end
        elseif order.status == "in_progress" and order.assignedTo then
            order.updatedBy = order.assignedTo
        end
        GuildieCraftsDB.orders[order.id] = order
        GuildieCrafts_AppendOrderToQueue(roomId, order.id)
        if not existing and GuildieCrafts_NotifyNewOrder then
            GuildieCrafts_NotifyNewOrder(order, room)
        end
        if GuildieCrafts.UI then
            GuildieCrafts_RefreshUI()
        end
    elseif msgType == MSG_STATUS then
        local orderId = parts[2]
        local order = GuildieCraftsDB.orders[orderId]
        if order then
            order.status = parts[3]
            order.updatedBy = parts[4]
            order.updatedAt = tonumber(parts[5]) or time()
            if parts[6] and parts[6] ~= "" then
                order.assignedTo = parts[6]
            elseif order.status == "in_progress" and order.updatedBy then
                order.assignedTo = order.updatedBy
            end
            if GuildieCrafts_NotifyOrderStatus then
                GuildieCrafts_NotifyOrderStatus(order, parts[4])
            end
            if GuildieCrafts.UI then
                GuildieCrafts_RefreshUI()
            end
        end
    elseif msgType == MSG_REMOVE then
        local orderId = parts[2]
        local order = GuildieCraftsDB.orders[orderId]
        if order and order.roomId then
            GuildieCrafts_RemoveOrderFromQueue(order.roomId, orderId)
        end
        GuildieCraftsDB.orders[orderId] = nil
        if GuildieCrafts.UI then
            GuildieCrafts_RefreshUI()
        end
    elseif msgType == MSG_REQUEST then
        local requester = parts[2]
        self:BroadcastAllRooms()
        for _, order in pairs(GuildieCraftsDB.orders or {}) do
            if order.roomId then
                local room = GuildieCrafts_GetRoom(order.roomId)
                if room and GuildieCrafts_IsSameGuild(room) and GuildieCrafts_IsRoomMember(room, requester) then
                    self:BroadcastOrder(order)
                end
            end
        end
        if GuildieCrafts_ShouldShareStock() then
            GuildieCrafts_ShareWorkshopStock()
        end
        if GuildieCrafts_ShouldShareRecipes() then
            GuildieCrafts_ShareWorkshopRecipes()
        end
        self:BroadcastAllOrderQueues(requester)
    elseif msgType == MSG_ROOM then
        local guild = DecodeField(parts[8])
        if guild and guild ~= GuildieCrafts_GetGuildName() then
            return
        end
        local existingRoom = GuildieCraftsDB.rooms[parts[2]]
        local incomingCoLeaders = parts[10] and ParseNames(parts[10]) or nil
        local incomingCollaborators = ParseNames(parts[6])
        local collaborators
        if sender == parts[4] then
            collaborators = incomingCollaborators
        else
            collaborators = MergeNameMaps(existingRoom and existingRoom.collaborators, incomingCollaborators)
        end
        local room = {
            id = parts[2],
            name = parts[3],
            leader = parts[4],
            open = parts[5] == "1",
            collaborators = collaborators,
            members = MergeNameMaps(
                existingRoom and existingRoom.members,
                parts[9] and ParseNames(parts[9])
            ),
            coLeaders = incomingCoLeaders
                or (existingRoom and existingRoom.coLeaders)
                or {},
            orderQueue = existingRoom and existingRoom.orderQueue or {},
            created = tonumber(parts[7]) or time(),
            guild = guild or GuildieCrafts_GetGuildName(),
            expansion = DecodeField(parts[11]) or GuildieCrafts_GetDefaultExpansion(),
            phase = DecodeField(parts[12]) or GuildieCrafts_GetDefaultPhase(),
            profession = DecodeField(parts[13]) or "jewelcrafting",
        }
        room.members[room.leader] = true
        GuildieCrafts_ApplyRoom(room)
    elseif msgType == MSG_JOIN then
        local room = GuildieCraftsDB.rooms[parts[2]]
        if not room then
            GuildieCrafts.Sync:RequestSync()
            return
        end
        room.members = room.members or {}
        room.members[parts[3]] = true
        GuildieCrafts_ApplyRoom(room)
        if GuildieCrafts_IsRoomMember(room, UnitName("player")) then
            self:BroadcastRoom(room)
            if GuildieCrafts_CanManageWorkshop(room, UnitName("player")) then
                self:BroadcastRoomOrders(room.id)
            end
        end
    elseif msgType == MSG_LEAVE then
        local room = GuildieCraftsDB.rooms[parts[2]]
        if room and room.members then
            room.members[parts[3]] = nil
            GuildieCrafts_ApplyRoom(room)
        end
    elseif msgType == MSG_COLLAB then
        local room = GuildieCraftsDB.rooms[parts[2]]
        if room then
            room.collaborators = room.collaborators or {}
            if parts[3] == "add" then
                room.collaborators[parts[4]] = true
                room.members[parts[4]] = true
                if parts[4] == UnitName("player") and GuildieCrafts_ShouldShareStock() then
                    GuildieCrafts_RefreshLocalStock()
                end
            else
                room.collaborators[parts[4]] = nil
            end
            GuildieCrafts_ApplyRoom(room)
        end
    elseif msgType == MSG_COLEADER then
        local room = GuildieCraftsDB.rooms[parts[2]]
        if room then
            room.coLeaders = room.coLeaders or {}
            if parts[3] == "add" then
                room.coLeaders[parts[4]] = true
                room.members = room.members or {}
                room.members[parts[4]] = true
            else
                room.coLeaders[parts[4]] = nil
            end
            GuildieCrafts_ApplyRoom(room)
        end
    elseif msgType == MSG_QUEUE then
        local room = GuildieCraftsDB.rooms[parts[2]]
        if room and GuildieCrafts_IsRoomMember(room, UnitName("player")) then
            if parts[3] == "" or parts[3] == "-" then
                room.orderQueue = {}
            else
                room.orderQueue = SplitMessage(parts[3], ";")
            end
            GuildieCrafts_ApplyRoom(room)
            if GuildieCrafts.UI then
                GuildieCrafts_RefreshUI()
            end
        end
    elseif msgType == MSG_STOCK then
        local room = GuildieCrafts_GetActiveRoom()
        if not room or not GuildieCrafts_HasJoinedWorkshop() then
            return
        end
        if not GuildieCrafts_AcceptsWorkshopStockReport(room, parts[2]) then
            return
        end
        GuildieCrafts_ApplyStockReport(parts[2], DecodeStock(parts[4]), parts[3])
    elseif msgType == MSG_RECIPES then
        local room = GuildieCrafts_GetActiveRoom()
        if not room or not GuildieCrafts_HasJoinedWorkshop() then
            return
        end
        if not GuildieCrafts_AcceptsWorkshopStockReport(room, parts[2]) then
            return
        end
        GuildieCrafts_ApplyRecipeReport(parts[2], DecodeRecipeIds(parts[3]))
    end
end

function Sync:GenerateOrderId()
    return string.format("%s-%d", UnitName("player"), time())
end
