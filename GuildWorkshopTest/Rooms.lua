GuildWorkshopTest = GuildWorkshop or {}

local function EnsureDB()
    GuildWorkshopTestDB = GuildWorkshopTestDB or {}
    GuildWorkshopTestDB.rooms = GuildWorkshopTestDB.rooms or {}
    GuildWorkshopTestDB.settings = GuildWorkshopTestDB.settings or { jcMode = false }
end

function GuildWorkshopTest_GetGuildName()
    if not IsInGuild() then
        return nil
    end
    return GetGuildInfo("player")
end

function GuildWorkshopTest_IsSameGuild(room)
    if not room then
        return false
    end
    local guild = GuildWorkshopTest_GetGuildName()
    if not guild then
        return false
    end
    if not room.guild then
        return true
    end
    return room.guild == guild
end

function GuildWorkshopTest_HasJoinedWorkshop()
    if not IsInGuild() then
        return false
    end
    local room = GuildWorkshopTest_GetActiveRoom()
    if not room or not room.open then
        return false
    end
    if not GuildWorkshopTest_IsSameGuild(room) then
        return false
    end
    return GuildWorkshopTest_IsRoomMember(room, UnitName("player"))
end

function GuildWorkshopTest_ValidateActiveRoom()
    EnsureDB()
    if not GuildWorkshopTest_HasJoinedWorkshop() then
        GuildWorkshopTestDB.settings.activeRoomId = nil
    end
end

function GuildWorkshopTest_PurgeNonGuildData()
    EnsureDB()
    local guild = GuildWorkshopTest_GetGuildName()
    if not guild then
        return
    end

    for id, room in pairs(GuildWorkshopTestDB.rooms) do
        if room.guild and room.guild ~= guild then
            GuildWorkshopTestDB.rooms[id] = nil
        end
    end

    for id, order in pairs(GuildWorkshopTestDB.orders) do
        local room = order.roomId and GuildWorkshopTestDB.rooms[order.roomId]
        if not room or not GuildWorkshopTest_IsSameGuild(room) then
            GuildWorkshopTestDB.orders[id] = nil
        end
    end

    GuildWorkshopTest_ValidateActiveRoom()
end

function GuildWorkshopTest_GetActiveRoomId()
    EnsureDB()
    return GuildWorkshopTestDB.settings.activeRoomId
end

function GuildWorkshopTest_GetActiveRoom()
    local roomId = GuildWorkshopTest_GetActiveRoomId()
    if not roomId then
        return nil
    end
    return GuildWorkshopTestDB.rooms[roomId]
end

function GuildWorkshopTest_GetRoom(roomId)
    EnsureDB()
    return roomId and GuildWorkshopTestDB.rooms[roomId]
end

function GuildWorkshopTest_GetOpenRooms()
    EnsureDB()
    if not IsInGuild() then
        return {}
    end
    local list = {}
    for _, room in pairs(GuildWorkshopTestDB.rooms) do
        if room.open and GuildWorkshopTest_IsSameGuild(room) then
            table.insert(list, room)
        end
    end
    table.sort(list, function(a, b)
        return (a.created or 0) > (b.created or 0)
    end)
    return list
end

function GuildWorkshopTest_IsRoomMember(room, player)
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

function GuildWorkshopTest_IsRoomCollaborator(room, player)
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

function GuildWorkshopTest_IsRoomLeader(room, player)
    return room and player and room.leader == player
end

function GuildWorkshopTest_IsRoomCoLeader(room, player)
    return room and player and room.coLeaders and room.coLeaders[player] == true
end

function GuildWorkshopTest_IsWorkshopOwner(room, player)
    return GuildWorkshopTest_IsRoomLeader(room, player)
end

function GuildWorkshopTest_CanManageWorkshop(room, player)
    if not room or not player then
        return false
    end
    return room.leader == player or GuildWorkshopTest_IsRoomCoLeader(room, player)
end

function GuildWorkshopTest_CanManageOrder(order)
    if not order then
        return false
    end
    local player = UnitName("player")
    if order.roomId then
        local room = GuildWorkshopTest_GetRoom(order.roomId)
        return GuildWorkshopTest_IsRoomCollaborator(room, player)
    end
    return false
end

function GuildWorkshopTest_CreateWorkshop(name, expansion, phase, profession)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local ok, err = GuildWorkshopTest_ValidateWorkshopDefinition(name, expansion, phase, profession)
    if not ok then
        return nil, err
    end

    name = strtrim(name or "")
    expansion = expansion or GuildWorkshopTest_GetDefaultExpansion()
    phase = phase or GuildWorkshopTest_GetDefaultPhase()
    profession = profession or "jewelcrafting"

    local player = UnitName("player")
    local room = {
        id = string.format("%s-%d", player, time()),
        name = name,
        expansion = expansion,
        phase = phase,
        profession = profession,
        leader = player,
        guild = GuildWorkshopTest_GetGuildName(),
        collaborators = {},
        coLeaders = {},
        members = { [player] = true },
        orderQueue = {},
        created = time(),
        open = true,
    }

    GuildWorkshopTestDB.rooms[room.id] = room
    GuildWorkshopTestDB.settings.activeRoomId = room.id
    GuildWorkshopTest.Sync:BroadcastRoom(room)
    GuildWorkshopTest.Sync:BroadcastJoin(room.id, player)
    if GuildWorkshopTest_ShouldShareStock() then
        GuildWorkshopTest_RefreshLocalStock()
    end
    return room
end

function GuildWorkshopTest_JoinWorkshop(roomId)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local room = GuildWorkshopTestDB.rooms[roomId]
    if not room or not room.open then
        return nil, "Workshop not found or closed."
    end
    if not GuildWorkshopTest_IsSameGuild(room) then
        return nil, "That workshop belongs to another guild."
    end

    local player = UnitName("player")
    room.members[player] = true
    GuildWorkshopTestDB.settings.activeRoomId = room.id
    GuildWorkshopTest.Sync:BroadcastJoin(room.id, player)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            GuildWorkshopTest.Sync:RequestSync()
        end)
    else
        GuildWorkshopTest.Sync:RequestSync()
    end
    return room
end

function GuildWorkshopTest_DeselectWorkshop()
    EnsureDB()
    if not GuildWorkshopTestDB.settings.activeRoomId then
        return nil, "No workshop selected."
    end

    GuildWorkshopTestDB.settings.activeRoomId = nil
    return true
end

function GuildWorkshopTest_LeaveWorkshop()
    EnsureDB()
    local roomId = GuildWorkshopTestDB.settings.activeRoomId
    if not roomId then
        return nil, "No workshop selected."
    end

    local room = GuildWorkshopTestDB.rooms[roomId]
    local player = UnitName("player")
    if room and room.members then
        room.members[player] = nil
    end
    GuildWorkshopTestDB.settings.activeRoomId = nil
    GuildWorkshopTest.Sync:BroadcastLeave(roomId, player)
    return true
end

function GuildWorkshopTest_CloseWorkshop(roomId)
    EnsureDB()
    local room = GuildWorkshopTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshopTest_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can close it."
    end

    room.open = false
    if GuildWorkshopTestDB.settings.activeRoomId == roomId then
        GuildWorkshopTestDB.settings.activeRoomId = nil
    end
    GuildWorkshopTest.Sync:BroadcastRoom(room)
    return true
end

function GuildWorkshopTest_AddCollaborator(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildWorkshopTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshopTest_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildWorkshopTest_GetCrafterLabel(GuildWorkshopTest_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can promote " .. crafters .. "."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.collaborators = room.collaborators or {}
    room.collaborators[playerName] = true
    GuildWorkshopTest.Sync:BroadcastCollaborator(roomId, "add", playerName)
    return true
end

function GuildWorkshopTest_PromoteMember(roomId, playerName)
    return GuildWorkshopTest_AddCollaborator(roomId, playerName)
end

function GuildWorkshopTest_AddCoLeader(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildWorkshopTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshopTest_IsWorkshopOwner(room, UnitName("player")) then
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
    GuildWorkshopTest.Sync:BroadcastCoLeader(roomId, "add", playerName)
    return true
end

function GuildWorkshopTest_RemoveCoLeader(roomId, playerName)
    EnsureDB()
    local room = GuildWorkshopTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshopTest_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can demote co-leaders."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = nil
    GuildWorkshopTest.Sync:BroadcastCoLeader(roomId, "remove", playerName)
    return true
end

function GuildWorkshopTest_DemoteCollaborator(roomId, playerName)
    return GuildWorkshopTest_RemoveCollaborator(roomId, playerName)
end

function GuildWorkshopTest_GetRoomMembers(room)
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

function GuildWorkshopTest_GetSortedRoomMembers(room)
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

function GuildWorkshopTest_IsPromotedJewelcrafter(room, player)
    if not room or not player then
        return false
    end
    return room.collaborators and room.collaborators[player] == true
end

function GuildWorkshopTest_GetWorkshopStockContributors(room)
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

function GuildWorkshopTest_GetWorkshopJCNames(room)
    return GuildWorkshopTest_GetWorkshopStockContributors(room)
end

function GuildWorkshopTest_IsWorkshopJC(room, player)
    return GuildWorkshopTest_IsRoomCollaborator(room, player)
end

function GuildWorkshopTest_ShouldShareStock()
    local room = GuildWorkshopTest_GetActiveRoom()
    if not room then
        return false
    end
    return GuildWorkshopTest_IsPromotedJewelcrafter(room, UnitName("player"))
end

function GuildWorkshopTest_AcceptsWorkshopStockReport(room, player)
    return GuildWorkshopTest_IsPromotedJewelcrafter(room, player)
end

function GuildWorkshopTest_RemoveCollaborator(roomId, playerName)
    EnsureDB()
    local room = GuildWorkshopTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildWorkshopTest_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildWorkshopTest_GetCrafterLabel(GuildWorkshopTest_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can remove " .. crafters .. "."
    end

    room.collaborators[playerName] = nil
    GuildWorkshopTest.Sync:BroadcastCollaborator(roomId, "remove", playerName)
    return true
end

function GuildWorkshopTest_ApplyRoom(room)
    EnsureDB()
    if not room or not room.id then
        return
    end
    GuildWorkshopTestDB.rooms[room.id] = room
    if GuildWorkshopTest.UI then
        GuildWorkshopTest_RefreshUI()
    end
end
