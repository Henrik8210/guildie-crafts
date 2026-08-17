-- In-game notifications for workshop crafters and order owners.
-- Real-time via guild addon sync; catch-up on login for offline changes.

local ADDON_PREFIX = "|cff00ccffGuildieCraftsTest|r"
local DEFAULT_SOUND = "TellMessage"
local CHECK_DELAY = 3

local function GetSettings()
    GuildieCraftsTestDB = GuildieCraftsTestDB or {}
    GuildieCraftsTestDB.settings = GuildieCraftsTestDB.settings or {}
    local settings = GuildieCraftsTestDB.settings
    if settings.notifyOrders == nil then
        settings.notifyOrders = true
    end
    if settings.notifyStatus == nil then
        settings.notifyStatus = true
    end
    if settings.notifySound == nil then
        settings.notifySound = true
    end
    settings.orderNotifyState = settings.orderNotifyState or {}
    settings.pendingNotifications = settings.pendingNotifications or {}
    return settings
end

local function QueueNotification(message)
    if not message or message == "" then
        return
    end
    local pending = GetSettings().pendingNotifications
    table.insert(pending, message)
    while #pending > 8 do
        table.remove(pending, 1)
    end
end

function GuildieCraftsTest_GetPendingNotifications()
    return GetSettings().pendingNotifications
end

function GuildieCraftsTest_ClearPendingNotifications()
    GetSettings().pendingNotifications = {}
end

local function SnapshotFromOrder(order)
    return {
        status = order.status or "pending",
        assignedTo = order.assignedTo or order.updatedBy,
    }
end

function GuildieCraftsTest_RecordOrderNotifyState(order)
    if not order or not order.id then
        return
    end
    GetSettings().orderNotifyState[order.id] = SnapshotFromOrder(order)
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

function GuildieCraftsTest_Notify(message, opts)
    if not message or message == "" then
        return
    end
    opts = opts or {}
    QueueNotification(message)
    print(ADDON_PREFIX .. " " .. message)
    if opts.playSound ~= false and GetSettings().notifySound then
        pcall(function()
            PlaySound(opts.sound or DEFAULT_SOUND)
        end)
    end
    if opts.flashMinimap ~= false and GuildieCraftsTest.Minimap and GuildieCraftsTest.Minimap.Pulse then
        GuildieCraftsTest.Minimap:Pulse()
    end
end

local function FormatOrderSummary(order)
    if not order then
        return "new order"
    end
    local summary = order.item or "order"
    if order.gems and #order.gems > 0 then
        summary = summary .. " (" .. #order.gems .. " gem"
        if #order.gems > 1 then
            summary = summary .. "s"
        end
        summary = summary .. ")"
    end
    return summary
end

function GuildieCraftsTest_NotifyNewOrder(order, room)
    if not order or not room then
        return
    end
    local settings = GetSettings()
    if not settings.notifyOrders then
        GuildieCraftsTest_RecordOrderNotifyState(order)
        return
    end

    local player = UnitName("player")
    if not player then
        return
    end
    if order.player == player then
        GuildieCraftsTest_RecordOrderNotifyState(order)
        return
    end
    if not GuildieCraftsTest_IsPromotedCrafter(room, player) then
        return
    end

    local crafterLabel = GuildieCraftsTest_GetCrafterLabel(GuildieCraftsTest_GetRoomProfession(room))
    local submitter = GuildieCraftsTest_ColorizePlayer(order.player)
    local summary = FormatOrderSummary(order)
    GuildieCraftsTest_Notify(string.format(
        "New %s order in |cff00ccff%s|r — %s: %s",
        string.lower(crafterLabel),
        room.name,
        submitter,
        summary
    ))
    GuildieCraftsTest_RecordOrderNotifyState(order)
end

function GuildieCraftsTest_NotifyOrderStatus(order, updatedBy)
    if not order then
        return
    end
    local settings = GetSettings()
    if not settings.notifyStatus then
        GuildieCraftsTest_RecordOrderNotifyState(order)
        return
    end

    local player = UnitName("player")
    if not player or order.player ~= player then
        return
    end
    if updatedBy == player then
        GuildieCraftsTest_RecordOrderNotifyState(order)
        return
    end

    local item = order.item or "your order"
    local actor = GuildieCraftsTest_ColorizePlayer(updatedBy or order.assignedTo or "someone")
    local message

    if order.status == "in_progress" then
        message = string.format("%s picked up %s.", actor, item)
    elseif order.status == "completed" then
        message = string.format("%s completed %s.", actor, item)
    elseif order.status == "cancelled" then
        message = string.format("%s was cancelled (%s).", item, actor)
    else
        GuildieCraftsTest_RecordOrderNotifyState(order)
        return
    end

    GuildieCraftsTest_Notify(message)
    GuildieCraftsTest_RecordOrderNotifyState(order)
end

local function ShouldNotifyOwnerCatchUp(prev, order)
    if order.status ~= "in_progress"
        and order.status ~= "completed"
        and order.status ~= "cancelled" then
        return false
    end
    if not prev then
        return true
    end
    local currentAssignee = order.assignedTo or order.updatedBy
    if prev.status ~= order.status then
        return true
    end
    return prev.assignedTo ~= currentAssignee
end

function GuildieCraftsTest_CheckMissedNotifications()
    if not IsInGuild() then
        return
    end

    local player = UnitName("player")
    if not player then
        return
    end

    local settings = GetSettings()
    local snapshots = settings.orderNotifyState
    local seenOrderIds = {}

    if not settings.notifyCatchUpInitialized then
        settings.notifyCatchUpInitialized = true
        for _, order in pairs(GuildieCraftsTestDB.orders or {}) do
            if order.id then
                GuildieCraftsTest_RecordOrderNotifyState(order)
                seenOrderIds[order.id] = true
            end
        end
        return
    end

    for _, order in pairs(GuildieCraftsTestDB.orders or {}) do
        if order.id and order.roomId then
            seenOrderIds[order.id] = true
            local room = GuildieCraftsTest_GetRoom(order.roomId)
            if room and GuildieCraftsTest_IsSameGuild(room) then
                local prev = snapshots[order.id]

                if order.player == player and settings.notifyStatus then
                    if ShouldNotifyOwnerCatchUp(prev, order) then
                        GuildieCraftsTest_NotifyOrderStatus(
                            order,
                            order.updatedBy or order.assignedTo
                        )
                    else
                        GuildieCraftsTest_RecordOrderNotifyState(order)
                    end
                elseif settings.notifyOrders
                    and order.player ~= player
                    and order.status == "pending"
                    and GuildieCraftsTest_IsPromotedCrafter(room, player)
                    and not prev then
                    GuildieCraftsTest_NotifyNewOrder(order, room)
                else
                    GuildieCraftsTest_RecordOrderNotifyState(order)
                end
            end
        end
    end

    for orderId in pairs(snapshots) do
        if not seenOrderIds[orderId] then
            snapshots[orderId] = nil
        end
    end
end

function GuildieCraftsTest_ScheduleMissedNotificationCheck(delay)
    After(delay or CHECK_DELAY, GuildieCraftsTest_CheckMissedNotifications)
end
