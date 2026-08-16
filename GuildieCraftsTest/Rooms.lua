GuildieCraftsTest = GuildieCraftsTest or {}

local function EnsureDB()
    GuildieCraftsTestDB = GuildieCraftsTestDB or {}
    GuildieCraftsTestDB.rooms = GuildieCraftsTestDB.rooms or {}
    GuildieCraftsTestDB.settings = GuildieCraftsTestDB.settings or { jcMode = false }
end

function GuildieCraftsTest_GetGuildName()
    if not IsInGuild() then
        return nil
    end
    return GetGuildInfo("player")
end

function GuildieCraftsTest_IsSameGuild(room)
    if not room then
        return false
    end
    local guild = GuildieCraftsTest_GetGuildName()
    if not guild then
        return false
    end
    if not room.guild then
        return true
    end
    return room.guild == guild
end

function GuildieCraftsTest_HasJoinedWorkshop()
    if not IsInGuild() then
        return false
    end
    local room = GuildieCraftsTest_GetActiveRoom()
    if not room or not room.open then
        return false
    end
    if not GuildieCraftsTest_IsSameGuild(room) then
        return false
    end
    return GuildieCraftsTest_IsRoomMember(room, UnitName("player"))
end

function GuildieCraftsTest_ValidateActiveRoom()
    EnsureDB()
    if not GuildieCraftsTest_HasJoinedWorkshop() then
        GuildieCraftsTestDB.settings.activeRoomId = nil
    end
end

function GuildieCraftsTest_PurgeNonGuildData()
    EnsureDB()
    local guild = GuildieCraftsTest_GetGuildName()
    if not guild then
        return
    end

    for id, room in pairs(GuildieCraftsTestDB.rooms) do
        if room.guild and room.guild ~= guild then
            GuildieCraftsTestDB.rooms[id] = nil
        end
    end

    for id, order in pairs(GuildieCraftsTestDB.orders) do
        local room = order.roomId and GuildieCraftsTestDB.rooms[order.roomId]
        if not room or not GuildieCraftsTest_IsSameGuild(room) then
            GuildieCraftsTestDB.orders[id] = nil
        end
    end

    GuildieCraftsTest_ValidateActiveRoom()
end

function GuildieCraftsTest_GetActiveRoomId()
    EnsureDB()
    return GuildieCraftsTestDB.settings.activeRoomId
end

function GuildieCraftsTest_GetActiveRoom()
    local roomId = GuildieCraftsTest_GetActiveRoomId()
    if not roomId then
        return nil
    end
    return GuildieCraftsTestDB.rooms[roomId]
end

function GuildieCraftsTest_GetRoom(roomId)
    EnsureDB()
    return roomId and GuildieCraftsTestDB.rooms[roomId]
end

function GuildieCraftsTest_GetOpenRooms()
    EnsureDB()
    if not IsInGuild() then
        return {}
    end
    local list = {}
    for _, room in pairs(GuildieCraftsTestDB.rooms) do
        if room.open and GuildieCraftsTest_IsSameGuild(room) then
            table.insert(list, room)
        end
    end
    table.sort(list, function(a, b)
        return (a.created or 0) > (b.created or 0)
    end)
    return list
end

function GuildieCraftsTest_IsRoomMember(room, player)
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

function GuildieCraftsTest_IsRoomCollaborator(room, player)
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

function GuildieCraftsTest_IsRoomLeader(room, player)
    return room and player and room.leader == player
end

function GuildieCraftsTest_IsRoomCoLeader(room, player)
    return room and player and room.coLeaders and room.coLeaders[player] == true
end

function GuildieCraftsTest_IsWorkshopOwner(room, player)
    return GuildieCraftsTest_IsRoomLeader(room, player)
end

function GuildieCraftsTest_CanManageWorkshop(room, player)
    if not room or not player then
        return false
    end
    return room.leader == player or GuildieCraftsTest_IsRoomCoLeader(room, player)
end

function GuildieCraftsTest_CanManageOrder(order)
    if not order then
        return false
    end
    local player = UnitName("player")
    if order.roomId then
        local room = GuildieCraftsTest_GetRoom(order.roomId)
        return GuildieCraftsTest_IsRoomCollaborator(room, player)
    end
    return false
end

function GuildieCraftsTest_CreateWorkshop(name, expansion, phase, profession)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local ok, err = GuildieCraftsTest_ValidateWorkshopDefinition(name, expansion, phase, profession)
    if not ok then
        return nil, err
    end

    name = strtrim(name or "")
    expansion = expansion or GuildieCraftsTest_GetDefaultExpansion()
    phase = phase or GuildieCraftsTest_GetDefaultPhase()
    profession = profession or "jewelcrafting"

    local player = UnitName("player")
    local room = {
        id = string.format("%s-%d", player, time()),
        name = name,
        expansion = expansion,
        phase = phase,
        profession = profession,
        leader = player,
        guild = GuildieCraftsTest_GetGuildName(),
        collaborators = {},
        coLeaders = {},
        members = { [player] = true },
        orderQueue = {},
        created = time(),
        open = true,
    }

    GuildieCraftsTestDB.rooms[room.id] = room
    GuildieCraftsTestDB.settings.activeRoomId = room.id
    GuildieCraftsTest.Sync:BroadcastRoom(room)
    GuildieCraftsTest.Sync:BroadcastJoin(room.id, player)
    if GuildieCraftsTest_ShouldShareStock() then
        GuildieCraftsTest_RefreshLocalStock()
    end
    return room
end

function GuildieCraftsTest_JoinWorkshop(roomId)
    EnsureDB()
    if not IsInGuild() then
        return nil, "You must be in a guild."
    end

    local room = GuildieCraftsTestDB.rooms[roomId]
    if not room or not room.open then
        return nil, "Workshop not found or closed."
    end
    if not GuildieCraftsTest_IsSameGuild(room) then
        return nil, "That workshop belongs to another guild."
    end

    local player = UnitName("player")
    room.members[player] = true
    GuildieCraftsTestDB.settings.activeRoomId = room.id
    GuildieCraftsTest.Sync:BroadcastJoin(room.id, player)
    if C_Timer and C_Timer.After then
        C_Timer.After(0.5, function()
            GuildieCraftsTest.Sync:RequestSync()
        end)
    else
        GuildieCraftsTest.Sync:RequestSync()
    end
    return room
end

function GuildieCraftsTest_DeselectWorkshop()
    EnsureDB()
    if not GuildieCraftsTestDB.settings.activeRoomId then
        return nil, "No workshop selected."
    end

    GuildieCraftsTestDB.settings.activeRoomId = nil
    return true
end

function GuildieCraftsTest_LeaveWorkshop()
    EnsureDB()
    local roomId = GuildieCraftsTestDB.settings.activeRoomId
    if not roomId then
        return nil, "No workshop selected."
    end

    local room = GuildieCraftsTestDB.rooms[roomId]
    local player = UnitName("player")
    if room and room.members then
        room.members[player] = nil
    end
    GuildieCraftsTestDB.settings.activeRoomId = nil
    GuildieCraftsTest.Sync:BroadcastLeave(roomId, player)
    return true
end

function GuildieCraftsTest_CloseWorkshop(roomId)
    EnsureDB()
    local room = GuildieCraftsTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCraftsTest_CanManageWorkshop(room, UnitName("player")) then
        return false, "Only the workshop leader or a co-leader can close it."
    end

    room.open = false
    if GuildieCraftsTestDB.settings.activeRoomId == roomId then
        GuildieCraftsTestDB.settings.activeRoomId = nil
    end
    GuildieCraftsTest.Sync:BroadcastRoom(room)
    return true
end

function GuildieCraftsTest_AddCollaborator(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildieCraftsTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCraftsTest_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildieCraftsTest_GetCrafterLabel(GuildieCraftsTest_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can promote " .. crafters .. "."
    end
    if not room.members or not room.members[playerName] then
        return false, "That player is not in the workshop."
    end

    room.collaborators = room.collaborators or {}
    room.collaborators[playerName] = true
    GuildieCraftsTest.Sync:BroadcastCollaborator(roomId, "add", playerName)
    GuildieCraftsTest.Sync:BroadcastRoom(room)
    if playerName == UnitName("player") and GuildieCraftsTest_ShouldShareStock() then
        GuildieCraftsTest_RefreshLocalStock()
    end
    return true
end

function GuildieCraftsTest_PromoteMember(roomId, playerName)
    return GuildieCraftsTest_AddCollaborator(roomId, playerName)
end

function GuildieCraftsTest_AddCoLeader(roomId, playerName)
    EnsureDB()
    playerName = strtrim(playerName or "")
    if playerName == "" then
        return false, "Select a member to promote."
    end

    local room = GuildieCraftsTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCraftsTest_IsWorkshopOwner(room, UnitName("player")) then
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
    GuildieCraftsTest.Sync:BroadcastCoLeader(roomId, "add", playerName)
    return true
end

function GuildieCraftsTest_RemoveCoLeader(roomId, playerName)
    EnsureDB()
    local room = GuildieCraftsTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCraftsTest_IsWorkshopOwner(room, UnitName("player")) then
        return false, "Only the workshop leader can demote co-leaders."
    end

    room.coLeaders = room.coLeaders or {}
    room.coLeaders[playerName] = nil
    GuildieCraftsTest.Sync:BroadcastCoLeader(roomId, "remove", playerName)
    return true
end

function GuildieCraftsTest_DemoteCollaborator(roomId, playerName)
    return GuildieCraftsTest_RemoveCollaborator(roomId, playerName)
end

function GuildieCraftsTest_GetRoomMembers(room)
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

function GuildieCraftsTest_GetSortedRoomMembers(room)
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

function GuildieCraftsTest_IsPromotedJewelcrafter(room, player)
    if not room or not player then
        return false
    end
    return room.collaborators and room.collaborators[player] == true
end

function GuildieCraftsTest_GetWorkshopStockContributors(room)
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

function GuildieCraftsTest_GetWorkshopJCNames(room)
    return GuildieCraftsTest_GetWorkshopStockContributors(room)
end

function GuildieCraftsTest_IsWorkshopJC(room, player)
    return GuildieCraftsTest_IsRoomCollaborator(room, player)
end

function GuildieCraftsTest_ShouldShareStock()
    local room = GuildieCraftsTest_GetActiveRoom()
    if not room then
        return false
    end
    return GuildieCraftsTest_IsPromotedJewelcrafter(room, UnitName("player"))
end

function GuildieCraftsTest_AcceptsWorkshopStockReport(room, player)
    return GuildieCraftsTest_IsPromotedJewelcrafter(room, player)
end

function GuildieCraftsTest_RemoveCollaborator(roomId, playerName)
    EnsureDB()
    local room = GuildieCraftsTestDB.rooms[roomId]
    if not room then
        return false, "Workshop not found."
    end
    if not GuildieCraftsTest_CanManageWorkshop(room, UnitName("player")) then
        local crafters = string.lower(GuildieCraftsTest_GetCrafterLabel(GuildieCraftsTest_GetRoomProfession(room)))
        return false, "Only the workshop leader or a co-leader can remove " .. crafters .. "."
    end

    room.collaborators[playerName] = nil
    GuildieCraftsTest.Sync:BroadcastCollaborator(roomId, "remove", playerName)
    GuildieCraftsTest.Sync:BroadcastRoom(room)
    return true
end

function GuildieCraftsTest_ApplyRoom(room)
    EnsureDB()
    if not room or not room.id then
        return
    end
    GuildieCraftsTestDB.rooms[room.id] = room
    if GuildieCraftsTest.UI then
        GuildieCraftsTest_RefreshUI()
    end
end
