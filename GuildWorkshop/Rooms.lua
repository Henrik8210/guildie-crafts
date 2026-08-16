GuildWorkshop = GuildWorkshop or {}

local function EnsureDB()
    GuildWorkshopDB = GuildWorkshopDB or {}
    GuildWorkshopDB.rooms = GuildWorkshopDB.rooms or {}
    GuildWorkshopDB.settings = GuildWorkshopDB.settings or { jcMode = false }
end

function GuildWorkshop_GetGuildName()
    if not IsInGuild() then
        return nil
    end
    return GetGuildInfo("player")
end

function GuildWorkshop_IsSameGuild(room)
    if not room then
        return false
    end
    local guild = GuildWorkshop_GetGuildName()
    if not guild then
        return false
    end
    if not room.guild then
        return true
    end
    return room.guild == guild
end

function GuildWorkshop_HasJoinedWorkshop()
    if not IsInGuild() then
        return false
    end
    local room = GuildWorkshop_GetActiveRoom()
    if not room or not room.open then
        return false
    end
    if not GuildWorkshop_IsSameGuild(room) then
        return false
    end
    return GuildWorkshop_IsRoomMember(room, UnitName("player"))
end

function GuildWorkshop_ValidateActiveRoom()
    EnsureDB()
    if not GuildWorkshop_HasJoinedWorkshop() then
        GuildWorkshopDB.settings.activeRoomId = nil
    end
end

function GuildWorkshop_PurgeNonGuildData()
    EnsureDB()
    local guild = GuildWorkshop_GetGuildName()
    if not guild then
        return
    end

    for id, room in pairs(GuildWorkshopDB.rooms) do
        if room.guild and room.guild ~= guild then
            GuildWorkshopDB.rooms[id] = nil
        end
    end

    for id, order in pairs(GuildWorkshopDB.orders) do
        local room = order.roomId and GuildWorkshopDB.rooms[order.roomId]
        if not room or not GuildWorkshop_IsSameGuild(room) then
            GuildWorkshopDB.orders[id] = nil
        end
    end

    GuildWorkshop_ValidateActiveRoom()
end

function GuildWorkshop_GetActiveRoomId()
    EnsureDB()
    return GuildWorkshopDB.settings.activeRoomId
end

function GuildWorkshop_GetActiveRoom()
    local roomId = GuildWorkshop_GetActiveRoomId()
    if not roomId then
        return nil
    end
    return GuildWorkshopDB.rooms[roomId]
end

function GuildWorkshop_GetRoom(roomId)
    EnsureDB()
    return roomId and GuildWorkshopDB.rooms[roomId]
end

function GuildWorkshop_GetOpenRooms()
    EnsureDB()
    if not IsInGuild() then
        return {}
    end
    local list = {}
    for _, room in pairs(GuildWorkshopDB.rooms) do
        if room.open and GuildWorkshop_IsSameGuild(room) then
            table.insert(list, room)
        end
    end
    table.sort(list, function(a, b)
        return (a.created or 0) > (b.created or 0)
    end)
    return list
end

function GuildWorkshop_IsRoomMember(room, player)
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

function GuildWorkshop_IsRoomCollaborator(room, player)
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

function GuildWorkshop_IsRoomLeader(room, player)
    return room and player and room.leader == player
end

function GuildWorkshop_IsRoomCoLeader(room, player)
    return room and player and room.coLeaders and room.coLeaders[player] == true
end

function GuildWorkshop_IsWorkshopOwner(room, player)
    return GuildWorkshop_IsRoomLeader(room, player)
end

function GuildWorkshop_CanManageWorkshop(room, player)
    if not room or not player then
        return false
    end
    return room.leader == player or GuildWorkshop_IsRoomCoLeader(room, player)
end

function GuildWorkshop_CanManageOrder(order)
    if not order then
        return false
    end
    local player = UnitName("player")
    if order.roomId then
        local room = GuildWorkshop_GetRoom(order.roomId)
        return GuildWorkshop_IsRoomCollaborator(room, player)
    end
    return false
end

function GuildWorkshop_CreateWorkshop(name, expansion, phase, profession)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local ok, err = GuildWorkshop_ValidateWorkshopDefinition(name, expansion, phase, profession)
    if not ok then
        return nil, err
    end

    name = strtrim(name or "")
    expansion = expansion or GuildWorkshop_GetDefaultExpansion()
    phase = phase or GuildWorkshop_GetDefaultPhase()
    profession = profession or "jewelcrafting"

    local player = UnitName("player")
    local room = {
        id = string.format("%s-%d", player, time()),
        name = name,
        expansion = expansion,
        phase = phase,
        profession = profession,
        leader = player,
        guild = GuildWorkshop_GetGuildName(),
        collaborators = {},
        coLeaders = {},
        members = { [player] = true },
        orderQueue = {},
        created = time(),
        open = true,
    }

    GuildWorkshopDB.rooms[room.id] = room
    GuildWorkshopDB.settings.activeRoomId = room.id
    GuildWorkshop.Sync:BroadcastRoom(room)
    GuildWorkshop.Sync:BroadcastJoin(room.id, player)
    if GuildWorkshop_ShouldShareStock() then
        GuildWorkshop_RefreshLocalStock()
    end
    return room
end

function GuildWorkshop_JoinWorkshop(roomId)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local room = GuildWorkshopDB.rooms[roomId]
    if not room or not room.open then
        return nil, "Workshop not found or closed."
    end
    if not GuildWorkshop_IsSameGuild(room) then
        return nil, "That workshop belongs to another guild."
    end

    local player = UnitName("player")
    room.members[player] = true
    GuildWorkshopDB.settings.activeRoomId = room.id
    GuildWorkshop.Sync:BroadcastJoin(room.id, player)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            GuildWorkshop.Sync:RequestSync()
        end)
    else
        GuildWorkshop.Sync:RequestSync()
    end
    return room
end

function GuildWorkshop_DeselectWorkshop()
    EnsureDB()
    if not GuildWorkshopDB.settings.activeRoomId then
        return nil, "No workshop selected."
    end

    GuildWorkshopDB.settings.activeRoomId = nil
    return true
end

function GuildWorkshop_LeaveWorkshop()
    EnsureDB()
    local roomId = GuildWorkshopDB.settings.activeRoomId
    if not roomId then
        return nil, "No workshop selected."
    end

    local room = GuildWorkshopDB.rooms[roomId]
    local player = UnitName("player")
    if room and room.members then
        room.members[player] = nil
    end
    GuildWorkshopDB.settings.activeRoomId = nil
    GuildWorkshop.Sync:BroadcastLeave(roomId, player)
    return true
end

function GuildWorkshop_CloseWorkshop(roomId)
    EnsureDB()
    local room = GuildWorkshopDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshop_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can close it."
    end

    room.open = false
    if GuildWorkshopDB.settings.activeRoomId == roomId then
        GuildWorkshopDB.settings.activeRoomId = nil
    end
    GuildWorkshop.Sync:BroadcastRoom(room)
    return true
end

function GuildWorkshop_AddCollaborator(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildWorkshopDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshop_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildWorkshop_GetCrafterLabel(GuildWorkshop_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can promote " .. crafters .. "."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.collaborators = room.collaborators or {}
    room.collaborators[playerName] = true
    GuildWorkshop.Sync:BroadcastCollaborator(roomId, "add", playerName)
    return true
end

function GuildWorkshop_PromoteMember(roomId, playerName)
    return GuildWorkshop_AddCollaborator(roomId, playerName)
end

function GuildWorkshop_AddCoLeader(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildWorkshopDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshop_IsWorkshopOwner(room, UnitName("player")) then
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
    GuildWorkshop.Sync:BroadcastCoLeader(roomId, "add", playerName)
    return true
end

function GuildWorkshop_RemoveCoLeader(roomId, playerName)
    EnsureDB()
    local room = GuildWorkshopDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshop_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can demote co-leaders."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = nil
    GuildWorkshop.Sync:BroadcastCoLeader(roomId, "remove", playerName)
    return true
end

function GuildWorkshop_DemoteCollaborator(roomId, playerName)
    return GuildWorkshop_RemoveCollaborator(roomId, playerName)
end

function GuildWorkshop_GetRoomMembers(room)
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

function GuildWorkshop_GetSortedRoomMembers(room)
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

function GuildWorkshop_IsPromotedJewelcrafter(room, player)
    if not room or not player then
        return false
    end
    return room.collaborators and room.collaborators[player] == true
end

function GuildWorkshop_GetWorkshopStockContributors(room)
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

function GuildWorkshop_GetWorkshopJCNames(room)
    return GuildWorkshop_GetWorkshopStockContributors(room)
end

function GuildWorkshop_IsWorkshopJC(room, player)
    return GuildWorkshop_IsRoomCollaborator(room, player)
end

function GuildWorkshop_ShouldShareStock()
    local room = GuildWorkshop_GetActiveRoom()
    if not room then
        return false
    end
    return GuildWorkshop_IsPromotedJewelcrafter(room, UnitName("player"))
end

function GuildWorkshop_AcceptsWorkshopStockReport(room, player)
    return GuildWorkshop_IsPromotedJewelcrafter(room, player)
end

function GuildWorkshop_RemoveCollaborator(roomId, playerName)
    EnsureDB()
    local room = GuildWorkshopDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshop_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildWorkshop_GetCrafterLabel(GuildWorkshop_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can remove " .. crafters .. "."
    end

    room.collaborators[playerName] = nil
    GuildWorkshop.Sync:BroadcastCollaborator(roomId, "remove", playerName)
    return true
end

function GuildWorkshop_ApplyRoom(room)
    EnsureDB()
    if not room or not room.id then
        return
    end
    GuildWorkshopDB.rooms[room.id] = room
    if GuildWorkshop.UI then
        GuildWorkshop_RefreshUI()
    end
end
