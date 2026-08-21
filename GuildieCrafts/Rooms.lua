GuildieCrafts = GuildieCrafts or {}

local function EnsureDB()
    GuildieCraftsDB = GuildieCraftsDB or {}
    GuildieCraftsDB.rooms = GuildieCraftsDB.rooms or {}
    GuildieCraftsDB.settings = GuildieCraftsDB.settings or { jcMode = false }
end

local function BroadcastSelfJoin(roomId)
    local player = UnitName("player")
    local _, class = UnitClass("player")
    GuildieCrafts_CachePlayerClass(player, class)
    GuildieCrafts.Sync:BroadcastJoin(roomId, player, class)
end

function GuildieCrafts_GetGuildName()
    if not IsInGuild() then
        return nil
    end
    return GetGuildInfo("player")
end

function GuildieCrafts_IsSameGuild(room)
    if not room then
        return false
    end
    local guild = GuildieCrafts_GetGuildName()
    if not guild then
        return false
    end
    if not room.guild then
        return true
    end
    return room.guild == guild
end

function GuildieCrafts_HasJoinedWorkshop()
    if not IsInGuild() then
        return false
    end
    local room = GuildieCrafts_GetActiveRoom()
    if not room or not room.open then
        return false
    end
    if not GuildieCrafts_IsSameGuild(room) then
        return false
    end
    return GuildieCrafts_IsRoomMember(room, UnitName("player"))
end

function GuildieCrafts_ValidateActiveRoom()
    EnsureDB()
    if not GuildieCrafts_HasJoinedWorkshop() then
        GuildieCraftsDB.settings.activeRoomId = nil
    end
end

function GuildieCrafts_PurgeNonGuildData()
    EnsureDB()
    local guild = GuildieCrafts_GetGuildName()
    if not guild then
        return
    end

    for id, room in pairs(GuildieCraftsDB.rooms) do
        if room.guild and room.guild ~= guild then
            GuildieCraftsDB.rooms[id] = nil
        end
    end

    for id, order in pairs(GuildieCraftsDB.orders) do
        local room = order.roomId and GuildieCraftsDB.rooms[order.roomId]
        if not room or not GuildieCrafts_IsSameGuild(room) then
            GuildieCraftsDB.orders[id] = nil
        end
    end

    GuildieCrafts_ValidateActiveRoom()
end

function GuildieCrafts_GetActiveRoomId()
    EnsureDB()
    return GuildieCraftsDB.settings.activeRoomId
end

function GuildieCrafts_GetActiveRoom()
    local roomId = GuildieCrafts_GetActiveRoomId()
    if not roomId then
        return nil
    end
    return GuildieCraftsDB.rooms[roomId]
end

function GuildieCrafts_GetRoom(roomId)
    EnsureDB()
    return roomId and GuildieCraftsDB.rooms[roomId]
end

function GuildieCrafts_GetOpenRooms()
    EnsureDB()
    if not IsInGuild() then
        return {}
    end
    local list = {}
    for _, room in pairs(GuildieCraftsDB.rooms) do
        if room.open and GuildieCrafts_IsSameGuild(room) then
            table.insert(list, room)
        end
    end
    table.sort(list, function(a, b)
        return (a.created or 0) > (b.created or 0)
    end)
    return list
end

function GuildieCrafts_IsRoomMember(room, player)
    if not room or not player then
        return false
    end
    if room.leader == player then
        return true
    end
    if room.coLeaders and room.coLeaders[player] then
        return true
    end
    return room.members and room.members[player] == true
end

function GuildieCrafts_IsRoomCollaborator(room, player)
    if not room or not player then
        return false
    end
    if room.leader == player then
        return true
    end
    if room.coLeaders and room.coLeaders[player] then
        return true
    end
    return room.collaborators and room.collaborators[player] == true
end

function GuildieCrafts_IsRoomLeader(room, player)
    return room and player and room.leader == player
end

function GuildieCrafts_IsRoomCoLeader(room, player)
    return room and player and room.coLeaders and room.coLeaders[player] == true
end

function GuildieCrafts_IsWorkshopOwner(room, player)
    return GuildieCrafts_IsRoomLeader(room, player)
end

function GuildieCrafts_CanManageWorkshop(room, player)
    if not room or not player then
        return false
    end
    return room.leader == player or GuildieCrafts_IsRoomCoLeader(room, player)
end

function GuildieCrafts_CanManageOrder(order)
    if not order then
        return false
    end
    local player = UnitName("player")
    if order.roomId then
        local room = GuildieCrafts_GetRoom(order.roomId)
        return GuildieCrafts_IsRoomCollaborator(room, player)
    end
    return false
end

function GuildieCrafts_CreateWorkshop(name, expansion, phase, profession)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local ok, err = GuildieCrafts_ValidateWorkshopDefinition(name, expansion, phase, profession)
    if not ok then
        return nil, err
    end

    name = strtrim(name or "")
    expansion = expansion or GuildieCrafts_GetDefaultExpansion()
    phase = phase or GuildieCrafts_GetDefaultPhase()
    local player = UnitName("player")
    local room = {
        id = string.format("%s-%d", player, time()),
        name = name,
        expansion = expansion,
        phase = phase,
        profession = profession,
        leader = player,
        guild = GuildieCrafts_GetGuildName(),
        collaborators = {},
        coLeaders = {},
        members = { [player] = true },
        orderQueue = {},
        created = time(),
        open = true,
    }

    GuildieCraftsDB.rooms[room.id] = room
    GuildieCraftsDB.settings.activeRoomId = room.id
    GuildieCrafts.Sync:BroadcastRoom(room)
    BroadcastSelfJoin(room.id)
    if GuildieCrafts_ShouldShareStock() then
        GuildieCrafts_RefreshLocalStock()
    end
    return room
end

function GuildieCrafts_EnsureJoinedAllOpenWorkshops()
    EnsureDB()
    if not IsInGuild() then
        return
    end

    local player = UnitName("player")
    for _, room in ipairs(GuildieCrafts_GetOpenRooms()) do
        room.members = room.members or {}
        if not GuildieCrafts_IsRoomMember(room, player) then
            room.members[player] = true
        end
        BroadcastSelfJoin(room.id)
    end
end

function GuildieCrafts_JoinWorkshop(roomId)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local room = GuildieCraftsDB.rooms[roomId]
    if not room or not room.open then
        return nil, "Workshop not found or closed."
    end
    if not GuildieCrafts_IsSameGuild(room) then
        return nil, "That workshop belongs to another guild."
    end

    local player = UnitName("player")
    room.members[player] = true
    GuildieCraftsDB.settings.activeRoomId = room.id
    BroadcastSelfJoin(room.id)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            GuildieCrafts.Sync:RequestSync()
        end)
    else
        GuildieCrafts.Sync:RequestSync()
    end
    return room
end

function GuildieCrafts_DeselectWorkshop()
    EnsureDB()
    if not GuildieCraftsDB.settings.activeRoomId then
        return nil, "No workshop selected."
    end

    GuildieCraftsDB.settings.activeRoomId = nil
    return true
end

function GuildieCrafts_LeaveWorkshop()
    EnsureDB()
    local roomId = GuildieCraftsDB.settings.activeRoomId
    if not roomId then
        return nil, "No workshop selected."
    end

    local room = GuildieCraftsDB.rooms[roomId]
    local player = UnitName("player")
    if room and room.members then
        room.members[player] = nil
    end
    GuildieCraftsDB.settings.activeRoomId = nil
    GuildieCrafts.Sync:BroadcastLeave(roomId, player)
    return true
end

function GuildieCrafts_CloseWorkshop(roomId)
    EnsureDB()
    local room = GuildieCraftsDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCrafts_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can close it."
    end

    room.open = false
    if GuildieCraftsDB.settings.activeRoomId == roomId then
        GuildieCraftsDB.settings.activeRoomId = nil
    end
    GuildieCrafts.Sync:BroadcastRoom(room)
    return true
end

function GuildieCrafts_AddCollaborator(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildieCraftsDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCrafts_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildieCrafts_GetCrafterLabel(GuildieCrafts_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can promote " .. crafters .. "."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.collaborators = room.collaborators or {}
    room.collaborators[playerName] = true
    GuildieCrafts.Sync:BroadcastCollaborator(roomId, "add", playerName)
    GuildieCrafts.Sync:BroadcastRoom(room)
    if playerName == UnitName("player") and GuildieCrafts_ShouldShareStock() then
        GuildieCrafts_RefreshLocalStock()
    end
    return true
end

function GuildieCrafts_PromoteMember(roomId, playerName)
    return GuildieCrafts_AddCollaborator(roomId, playerName)
end

function GuildieCrafts_AddCoLeader(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildieCraftsDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCrafts_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can promote co-leaders."
    end
    if playerName == room.leader then
        return false, "The workshop leader is already in charge."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = true
    room.members[playerName] = true
    GuildieCrafts.Sync:BroadcastCoLeader(roomId, "add", playerName)
    return true
end

function GuildieCrafts_RemoveCoLeader(roomId, playerName)
    EnsureDB()
    local room = GuildieCraftsDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCrafts_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can demote co-leaders."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = nil
    GuildieCrafts.Sync:BroadcastCoLeader(roomId, "remove", playerName)
    return true
end

function GuildieCrafts_DemoteCollaborator(roomId, playerName)
    return GuildieCrafts_RemoveCollaborator(roomId, playerName)
end

function GuildieCrafts_GetRoomMembers(room)
    local members = {}
    if not room or not room.members then
        return members
    end
    for name in pairs(room.members) do
        table.insert(members, name)
    end
    table.sort(members)
    return members
end

function GuildieCrafts_GetSortedRoomMembers(room)
    local coLeaders = {}
    local jewelcrafters = {}
    local members = {}
    if not room or not room.members then
        return {}
    end

    for name in pairs(room.members) do
        if name == room.leader then
            -- leader handled separately
        elseif room.coLeaders and room.coLeaders[name] then
            table.insert(coLeaders, name)
        elseif room.collaborators and room.collaborators[name] then
            table.insert(jewelcrafters, name)
        else
            table.insert(members, name)
        end
    end

    table.sort(coLeaders)
    table.sort(jewelcrafters)
    table.sort(members)

    local sorted = {}
    if room.leader then
        table.insert(sorted, room.leader)
    end
    for _, name in ipairs(coLeaders) do
        table.insert(sorted, name)
    end
    for _, name in ipairs(jewelcrafters) do
        table.insert(sorted, name)
    end
    for _, name in ipairs(members) do
        table.insert(sorted, name)
    end
    return sorted
end

function GuildieCrafts_IsPromotedJewelcrafter(room, player)
    if not room or not player then
        return false
    end
    return room.collaborators and room.collaborators[player] == true
end

function GuildieCrafts_IsPromotedCrafter(room, player)
    return GuildieCrafts_IsPromotedJewelcrafter(room, player)
end

function GuildieCrafts_GetWorkshopStockContributors(room)
    local names = {}
    if not room then
        return names
    end
    for name in pairs(room.collaborators or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function GuildieCrafts_GetWorkshopJCNames(room)
    return GuildieCrafts_GetWorkshopStockContributors(room)
end

function GuildieCrafts_IsWorkshopJC(room, player)
    return GuildieCrafts_IsRoomCollaborator(room, player)
end

function GuildieCrafts_ShouldShareStock()
    local room = GuildieCrafts_GetActiveRoom()
    if not room then
        return false
    end
    return GuildieCrafts_IsPromotedJewelcrafter(room, UnitName("player"))
end

function GuildieCrafts_AcceptsWorkshopStockReport(room, player)
    return GuildieCrafts_IsPromotedJewelcrafter(room, player)
end

function GuildieCrafts_RemoveCollaborator(roomId, playerName)
    EnsureDB()
    local room = GuildieCraftsDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCrafts_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildieCrafts_GetCrafterLabel(GuildieCrafts_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can remove " .. crafters .. "."
    end

    room.collaborators[playerName] = nil
    GuildieCrafts.Sync:BroadcastCollaborator(roomId, "remove", playerName)
    GuildieCrafts.Sync:BroadcastRoom(room)
    return true
end

function GuildieCrafts_ApplyRoom(room)
    EnsureDB()
    if not room or not room.id then
        return
    end
    GuildieCraftsDB.rooms[room.id] = room
    if room.open and GuildieCrafts_IsSameGuild(room) then
        GuildieCrafts_EnsureJoinedAllOpenWorkshops()
    end
    if GuildieCrafts.UI then
        GuildieCrafts_RefreshUI()
    end
end
