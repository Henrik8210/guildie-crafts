local ADDON_NAME = ...

GuildieCraftsTest = GuildieCraftsTest or {}
local MinimapBtn = {}
GuildieCraftsTest.Minimap = MinimapBtn

local BUTTON_SIZE = 31
local MINIMAP_RADIUS = 80

local function GetAngle()
    GuildieCraftsTestDB.settings = GuildieCraftsTestDB.settings or {}
    return GuildieCraftsTestDB.settings.minimapAngle or 220
end

local function SetAngle(angle)
    GuildieCraftsTestDB.settings = GuildieCraftsTestDB.settings or {}
    GuildieCraftsTestDB.settings.minimapAngle = angle
end

local function UpdatePosition(button)
    local angle = math.rad(GetAngle())
    local x = math.cos(angle) * MINIMAP_RADIUS
    local y = math.sin(angle) * MINIMAP_RADIUS
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function RegisterButtonClicks(button)
    if not button.RegisterForClicks then
        return
    end

    -- TBC Anniversary uses the modern single-argument form.
    if pcall(function() button:RegisterForClicks("AnyUp") end) then
        return
    end
    if pcall(function() button:RegisterForClicks(false, "LeftButtonUp", "RightButtonUp") end) then
        return
    end
    pcall(function() button:RegisterForClicks("LeftButton", "RightButton") end)
end

function MinimapBtn:Init()
    if self.button then
        return
    end
    if not Minimap then
        return
    end

    local button = CreateFrame("Button", "GuildieCraftsTestMinimapButton", Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("HIGH")
    button:SetFrameLevel(20)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(GuildieCraftsTest_GetDefaultWorkshopIcon())

    RegisterButtonClicks(button)
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(_, mouseButton)
        MinimapBtn:StopPulse()
        if not GuildieCraftsTest_EnsureUI() then
            return
        end
        if mouseButton == "RightButton" then
            if GuildieCraftsTest.UI then
                GuildieCraftsTest.UI:ShowTab("workshop")
                GuildieCraftsTest.UI:Show()
            end
            return
        end

        if GuildieCraftsTest.UI then
            GuildieCraftsTest.UI:Toggle()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(s)
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            SetAngle(math.deg(math.atan2(py - my, px - mx)))
            UpdatePosition(s)
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Guildie Crafts", 1, 1, 1)

        local pending = GuildieCraftsTest_GetPendingNotifications and GuildieCraftsTest_GetPendingNotifications() or {}
        if #pending > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Notifications:", 1, 0.82, 0)
            for _, message in ipairs(pending) do
                GameTooltip:AddLine(message, 1, 1, 1, true)
            end
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: open orders", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: workshop", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Drag to move icon", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition(button)
    button:Show()
    self.button = button
end

function MinimapBtn:EnsurePulseFrame()
    if self.pulseFrame then
        return self.pulseFrame
    end

    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function()
        local button = MinimapBtn.button
        if not button or not MinimapBtn.pulseActive then
            frame:Hide()
            if button then
                button:SetAlpha(1)
            end
            return
        end
        button:SetAlpha(0.35 + 0.65 * math.abs(math.sin(GetTime() * 3)))
    end)
    self.pulseFrame = frame
    return frame
end

function MinimapBtn:Pulse()
    if not self.button then
        return
    end
    self.pulseActive = true
    self:EnsurePulseFrame():Show()
end

function MinimapBtn:StopPulse()
    self.pulseActive = false
    if self.pulseFrame then
        self.pulseFrame:Hide()
    end
    if self.button then
        self.button:SetAlpha(1)
    end
    if GuildieCraftsTest_ClearPendingNotifications then
        GuildieCraftsTest_ClearPendingNotifications()
    end
end
