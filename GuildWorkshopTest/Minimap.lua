local ADDON_NAME = ...

GuildWorkshopTest = GuildWorkshopTest or {}
local MinimapBtn = {}
GuildWorkshopTest.Minimap = MinimapBtn

local BUTTON_SIZE = 31
local MINIMAP_RADIUS = 80

local function GetAngle()
    GuildWorkshopTestDB.settings = GuildWorkshopTestDB.settings or {}
    return GuildWorkshopTestDB.settings.minimapAngle or 220
end

local function SetAngle(angle)
    GuildWorkshopTestDB.settings = GuildWorkshopTestDB.settings or {}
    GuildWorkshopTestDB.settings.minimapAngle = angle
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

    local button = CreateFrame("Button", "GuildWorkshopTestMinimapButton", Minimap)
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
    icon:SetTexture("Interface\\Icons\\Inv_Jewelcrafting_CrimsonSpinel_02")

    RegisterButtonClicks(button)
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnClick", function(_, mouseButton)
        if not GuildWorkshopTest_EnsureUI() then
            return
        end
        if mouseButton == "RightButton" then
            if GuildWorkshopTest.UI then
                GuildWorkshopTest.UI:ShowTab("workshop")
                GuildWorkshopTest.UI:Show()
            end
            return
        end

        if GuildWorkshopTest.UI then
            GuildWorkshopTest.UI:Toggle()
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
        GameTooltip:SetText("GuildWorkshopTest", 1, 1, 1)
        GameTooltip:AddLine("Left-click: open orders", 1, 0.82, 0)
        GameTooltip:AddLine("Drag to move icon", 1, 0.82, 0)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition(button)
    button:Show()
    self.button = button
end
