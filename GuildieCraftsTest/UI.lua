local ADDON_NAME = ...

GuildieCraftsTest = GuildieCraftsTest or {}
local UI = GuildieCraftsTest.UI or {}
GuildieCraftsTest.UI = UI

local FRAME_WIDTH = 540
local FRAME_HEIGHT = 660
local ORDER_ROW_HEIGHT = 100
local ORDER_ROW_GAP = 10
local ORDER_ROW_VALUE_X = 80
local ORDER_ROW_IN_PROGRESS_BAND = 24
local RECIPE_ROW_HEIGHT = 22
local RECIPE_SECTION_GAP = 18
local RECIPE_HEADER_AFTER_GAP = 8
local ORDER_DIALOG_WIDTH = 430
local ORDER_DIALOG_MIN_HEIGHT = 400
local ORDER_DIALOG_TITLE_HEIGHT = 50
local ORDER_DIALOG_PORTRAIT_SIZE = 39
local ORDER_DIALOG_ICON = "Interface\\MailFrame\\Mail-Icon"
local ORDER_DIALOG_ROW_GAP = 32
local ORDER_DIALOG_WARNING_HEIGHT = 36
local ORDER_DIALOG_WARNING_GAP = 2
local ORDER_DIALOG_NOTES_GAP = 16
local ORDER_DIALOG_MATERIALS_ACK_GAP = 10
local ORDER_DIALOG_MATERIALS_ACK_HEIGHT = 36
local GEM_RECIPE_WARNING = "|cffffff00Warning: Your guild has not yet obtained\nthe recipe for this gem cut.|r"
local CRAFT_RECIPE_WARNING = "|cffffff00Warning: Your guild has not yet obtained\nthe recipe for this craft.|r"
local CRAFT_MATERIALS_ACK_TEXT = "I have the rest of the materials for this craft."
local ORDER_DIALOG_FOOTER_HEIGHT = 56
local ORDER_DIALOG_DROPDOWN_WIDTH = 250
local ORDER_DIALOG_FIELD_X = 90
local ORDER_DIALOG_LABEL_V_OFFSET = 6
local ORDER_DIALOG_DROPDOWN_TEXT_INSET = 18
local QUEUE_FRAME_MARGIN = 12
local QUEUE_INSET_PADDING = 12
local QUEUE_SCROLLBAR_WIDTH = 28
local QUEUE_SCROLLBAR_GUTTER = 12
local QUEUE_HEADER_BAND = 38
local WORKSHOP_SECTION_GAP = 14
local WORKSHOP_MEMBERS_GAP = 12
local WORKSHOP_LABEL_X = 16
local WORKSHOP_CONTROL_X = 120
local WORKSHOP_DROPDOWN_WIDTH = 280
local WORKSHOP_FORM_ROW_GAP = 28
local WORKSHOP_CONTROL_V_OFFSET = 4
local NOTES_PLACEHOLDER = "Fx. this is my BiS gear..."
local GEM_PLACEHOLDER = "Select gem..."
local GEAR_TYPE_PLACEHOLDER = "Select type..."
local GEAR_CLASS_PLACEHOLDER = "Select class..."
local ROLE_PLACEHOLDER = "Select role..."
local CRAFT_CATEGORY_PLACEHOLDER = "Select category..."
local CRAFT_PLACEHOLDER = "Select gear..."

local function RegisterCloseWorkshopPopup()
    if GuildieCraftsTest.closeWorkshopPopupRegistered then
        return
    end
    GuildieCraftsTest.closeWorkshopPopupRegistered = true
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["GuildieCraftsTest_CONFIRM_CLOSE_WORKSHOP"] = {
        text = "Are you sure you wish to close the workshop %s?",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self)
            local data = self.data
            if not data or not data.roomId then
                return
            end
            local ok, err = GuildieCraftsTest_CloseWorkshop(data.roomId)
            if not ok then
                print("|cff00ccffGuildieCraftsTest|r " .. (err or "Could not close workshop."))
            else
                print("|cff00ccffGuildieCraftsTest|r Workshop closed.")
            end
            GuildieCraftsTest_RefreshUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function ConfirmCloseWorkshop(room)
    if not room or not StaticPopup_Show then
        return
    end
    RegisterCloseWorkshopPopup()
    local dialog = StaticPopup_Show("GuildieCraftsTest_CONFIRM_CLOSE_WORKSHOP", room.name)
    if dialog then
        dialog.data = {
            roomId = room.id,
            roomName = room.name,
        }
    end
end

local GEM_COLORS = {
    Red = "ff2020",
    Yellow = "ffff00",
    Orange = "ff8000",
    Blue = "0070dd",
    Green = "1eff00",
    Purple = "a335ee",
    Unknown = "ffffff",
}

local ITEM_QUALITY_COLORS = {
    epic = "a335ee",
}

local function ColorizeItem(name, quality)
    quality = quality or "epic"
    local color = ITEM_QUALITY_COLORS[quality] or "ffffff"
    return string.format("|cff%s%s|r", color, name)
end

local function ColorizeGem(name)
    local color = GEM_COLORS[GuildieCraftsTest_GetGemColor(name)] or GEM_COLORS.Unknown
    return string.format("|cff%s%s|r", color, name)
end

local function GetQueueInsetWidth()
    return FRAME_WIDTH - (QUEUE_FRAME_MARGIN * 2)
end

local function GetQueueScrollWidth()
    return GetQueueInsetWidth() - QUEUE_INSET_PADDING
end

local function GetQueueRightInset()
    return QUEUE_SCROLLBAR_WIDTH + QUEUE_SCROLLBAR_GUTTER
end

local function GetQueueContentWidth()
    return GetQueueScrollWidth() - QUEUE_SCROLLBAR_WIDTH - QUEUE_SCROLLBAR_GUTTER
end

local function LayoutQueueScrollbarOnce(inset)
    local scrollBar = _G["GuildieCraftsTestScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", inset, "TOPRIGHT", 0, -QUEUE_HEADER_BAND)
        scrollBar:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, QUEUE_INSET_PADDING)
        scrollBar:SetWidth(QUEUE_SCROLLBAR_WIDTH)
    end
end

local function GreyGem(name)
    return "|cff888888" .. name .. "|r"
end

local function GetOrderRowBandExtra(order)
    if order and order.status == "in_progress" then
        return ORDER_ROW_IN_PROGRESS_BAND
    end
    return 0
end

local function AttachTextPulseAnimation(fontString, parent)
    local t = 0
    parent:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        local alpha = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 1.8))
        fontString:SetAlpha(alpha)
    end)
    parent:SetScript("OnHide", function()
        parent:SetScript("OnUpdate", nil)
        fontString:SetAlpha(1)
    end)
end

local function CreateInProgressBand(row, order, contentWidth)
    local band = CreateFrame("Frame", nil, row)
    band:SetPoint("TOPLEFT", 1, -1)
    band:SetSize(contentWidth - 2, ORDER_ROW_IN_PROGRESS_BAND)

    local bandBg = band:CreateTexture(nil, "BACKGROUND")
    bandBg:SetAllPoints()
    bandBg:SetColorTexture(0.08, 0.20, 0.36, 0.92)

    local bandLine = band:CreateTexture(nil, "BORDER")
    bandLine:SetPoint("BOTTOMLEFT", 0, 0)
    bandLine:SetPoint("BOTTOMRIGHT", 0, 0)
    bandLine:SetHeight(1)
    bandLine:SetColorTexture(0.35, 0.55, 0.78, 0.55)

    local statusText = band:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("CENTER", band, "CENTER", 0, 0)
    statusText:SetText(GuildieCraftsTest_GetOrderStatusLabel(order))
    AttachTextPulseAnimation(statusText, band)

    return band
end

local function CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetText(text)
    return label
end

local function SafeSetSize(frame, width, height)
    if not frame then
        return
    end
    width = tonumber(width) or 1
    height = tonumber(height) or 1
    if frame.SetSize then
        frame:SetSize(width, height)
    else
        frame:SetWidth(width)
        frame:SetHeight(height)
    end
end

local function SafeSetWidth(frame, width)
    if not frame then
        return
    end
    frame:SetWidth(tonumber(width) or 1)
end

local function SetFrameTitle(frame, text)
    if frame.TitleText then
        frame.TitleText:SetText(text)
    else
        local title = _G[frame:GetName() .. "TitleText"]
        if title then
            title:SetText(text)
        end
    end
end

local function SetFramePortraitIcon(frame, texturePath)
    if not frame or not texturePath then
        return
    end
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    local isAddonPath = type(texturePath) == "string" and texturePath:find("AddOns\\", 1, true) ~= nil
    if isAddonPath and portrait then
        portrait:SetTexture(texturePath)
        if portrait.SetTexCoord then
            -- Zoom out slightly inside the circular portrait mask.
            portrait:SetTexCoord(-0.05, 1.05, -0.05, 1.05)
        end
        return
    end
    if frame.SetPortraitTexture then
        frame:SetPortraitTexture(texturePath)
        return
    end
    if not portrait then
        return
    end
    if SetPortraitToTexture and type(texturePath) == "string" then
        SetPortraitToTexture(portrait, texturePath)
        return
    end
    portrait:SetTexture(texturePath)
end

local function ApplyParchmentBackground(parent)
    local tl = parent:CreateTexture(nil, "BACKGROUND")
    tl:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookPage-TopLeft")
    tl:SetPoint("TOPLEFT", 0, 0)
    tl:SetSize(256, 256)

    local tr = parent:CreateTexture(nil, "BACKGROUND")
    tr:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookPage-TopRight")
    tr:SetPoint("TOPRIGHT", 0, 0)
    tr:SetSize(256, 256)

    local bl = parent:CreateTexture(nil, "BACKGROUND")
    bl:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookPage-BotLeft")
    bl:SetPoint("BOTTOMLEFT", 0, 0)
    bl:SetSize(256, 256)

    local br = parent:CreateTexture(nil, "BACKGROUND")
    br:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookPage-BotRight")
    br:SetPoint("BOTTOMRIGHT", 0, 0)
    br:SetSize(256, 256)
end

local function ApplyAddonPanelBackground(frame)
    local base = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    base:SetAllPoints()
    base:SetColorTexture(0.20, 0.17, 0.13, 1)

    local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    fill:SetAllPoints()
    fill:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background")
    if fill.SetHorizTile then
        fill:SetHorizTile(true)
    end
    if fill.SetVertTile then
        fill:SetVertTile(true)
    end

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end

    ApplyParchmentBackground(frame)
end

local function CreateInsetPanel(parent)
    local panel = CreateFrame("Frame", nil, parent)
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
    end
    return panel
end

local function CreateMainFrameHelper()
    local ok, frame = pcall(CreateFrame, "Frame", "GuildieCraftsTestFrame", UIParent, "PortraitFrameTemplate")
    if ok and frame then
        return frame
    end
    frame = CreateFrame("Frame", "GuildieCraftsTestFrame", UIParent)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    return frame
end

local function HideOpenDropdownLists()
    for i = 1, (UIDROPDOWNMENU_MAXLEVELS or 2) do
        local list = _G["DropDownList" .. i]
        if list and list.IsShown and list:IsShown() then
            list:Hide()
        end
    end
end

local function SafeCloseDropdownMenus()
    HideOpenDropdownLists()
end

local function EnableDropdownDismissLayer(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function()
        HideOpenDropdownLists()
    end)
end

local function ConfigureOrderDropdown(dropdown, width)
    UIDropDownMenu_SetWidth(dropdown, width or ORDER_DIALOG_DROPDOWN_WIDTH)

    local name = dropdown:GetName()
    if not name then
        return
    end

    local button = _G[name .. "Button"]
    if not button then
        return
    end

    if UIDropDownMenu_SetAnchor then
        UIDropDownMenu_SetAnchor(dropdown, 0, 0, "TOPRIGHT", button, "BOTTOMRIGHT")
    end
end

local function SetDropdownDisplayText(dropdown, text)
    if UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(dropdown, text or "")
        return
    end
    local label = _G[dropdown:GetName() .. "Text"]
    if label then
        label:SetText(text or "")
    end
end

local function HideOrderDialogSilently()
    if not GuildieCraftsTest.UI or not GuildieCraftsTest.UI.frame then
        return
    end
    local f = GuildieCraftsTest.UI.frame
    if f.orderDialogOverlay then
        f.orderDialogOverlay:Hide()
    end
    if f.orderDialog then
        f.orderDialog:Hide()
    end
end

local function MarkDropdownSelection(info, selected)
    info.checked = selected
    if selected then
        info.colorCode = "|cff00ff00"
    end
end

local function IsNotesPlaceholder(text)
    return strtrim(text or "") == NOTES_PLACEHOLDER
end

local function GetNotesInputText(editBox)
    local text = strtrim(editBox:GetText() or "")
    if IsNotesPlaceholder(text) then
        return ""
    end
    return text
end

local function SetNotesPlaceholderState(editBox, active)
    if active then
        editBox:SetTextColor(1, 1, 1)
        if IsNotesPlaceholder(editBox:GetText()) then
            editBox:SetText("")
        end
        return
    end

    if GetNotesInputText(editBox) == "" then
        editBox:SetText(NOTES_PLACEHOLDER)
        editBox:SetTextColor(0.55, 0.55, 0.55)
    end
end

local function ResetNotesInput(editBox)
    editBox:SetText(NOTES_PLACEHOLDER)
    editBox:SetTextColor(0.55, 0.55, 0.55)
end

local function GetAddonVersion()
    if GuildieCraftsTest_GetVersion then
        return GuildieCraftsTest_GetVersion()
    end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "?"
    end
    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(ADDON_NAME, "Version") or "?"
    end
    return "?"
end

function UI:BuildDropdownCaches()
    if self._dropdownCachesReady then
        return
    end
    self._dropdownCachesReady = true

    self.gemMenuEntries = {}
    table.insert(self.gemMenuEntries, { kind = "none" })
    local currentColor = nil
    for _, gem in ipairs(GuildieCraftsTest_GetCutGems()) do
        if gem.color ~= currentColor then
            currentColor = gem.color
            table.insert(self.gemMenuEntries, { kind = "header", text = gem.color .. " gems" })
        end
        table.insert(self.gemMenuEntries, { kind = "gem", gem = gem })
    end
end

function UI:RefreshJoinDropdownCache()
    self.joinRoomOptions = GuildieCraftsTest_GetOpenRooms()
end

function UI:Init()
    if self.frame then
        return
    end
    self:BuildDropdownCaches()
    self:CreateMainFrame()
    self:CreateTabs()
    self:CreateOrderDialog()
    self:CreateOrderForm()
    self:CreateQueueList()
    self:CreateWorkshopPanel()
    self:CreateStockPanel()
    self:CreateRecipesPanel()
    self:ShowTab("workshop")
    self:Refresh()
end

function UI:CreateMainFrame()
    local f = CreateMainFrameHelper()
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    GuildieCraftsTest_RegisterEscapeFrame(f)

    f:SetScript("OnHide", function()
        HideOpenDropdownLists()
        HideOrderDialogSilently()
    end)

    SetFrameTitle(f, "Guildie Crafts")
    f.portraitIcon = GuildieCraftsTest_GetDefaultWorkshopPortrait()
    SetFramePortraitIcon(f, f.portraitIcon)

    f.subtitle = CreateLabel(f, "Guildie Crafts — orders, stock, and recipes", "GameFontHighlightSmall")
    f.subtitle:SetPoint("TOP", 0, -28)

    f.roomLabel = CreateLabel(f, "", "GameFontHighlightSmall")
    f.roomLabel:SetPoint("TOPLEFT", 72, -50)
    f.roomLabel:SetWidth(FRAME_WIDTH - 160)
    f.roomLabel:SetJustifyH("LEFT")

    f.jcLabel = CreateLabel(f, "", "GameFontNormalSmall")
    f.jcLabel:SetPoint("TOPLEFT", f.roomLabel, "BOTTOMLEFT", 0, -6)
    f.jcLabel:SetWidth(FRAME_WIDTH - 160)
    f.jcLabel:SetJustifyH("LEFT")

    f.creditsDev = CreateLabel(f, "Developed by " .. GuildieCraftsTest_ColorizePlayer("Nobunda", "SHAMAN"), "GameFontDisableSmall")
    f.creditsDev:SetPoint("BOTTOM", 0, 22)
    f.creditsDev:SetJustifyH("CENTER")

    f.creditsTest = CreateLabel(f, "Tested by " .. GuildieCraftsTest_ColorizePlayer("Justtwo", "WARLOCK"), "GameFontDisableSmall")
    f.creditsTest:SetPoint("BOTTOM", 0, 8)
    f.creditsTest:SetJustifyH("CENTER")

    f.versionLabel = CreateLabel(f, "v" .. GetAddonVersion(), "GameFontDisableSmall")
    f.versionLabel:SetPoint("BOTTOMRIGHT", -16, 10)

    f.queueInset = CreateInsetPanel(f)
    f.queueInset:SetPoint("TOPLEFT", 12, -108)
    f.queueInset:SetPoint("BOTTOMRIGHT", -12, 36)
    ApplyAddonPanelBackground(f.queueInset)

    EnableDropdownDismissLayer(f)
    EnableDropdownDismissLayer(f.queueInset)

    self.frame = f
end

function UI:CreateTabs()
    local f = self.frame
    f.tabButtons = {}
    local tabs = {
        { id = "workshop", label = "Workshop" },
        { id = "orders", label = "Orders" },
        { id = "completed", label = "Done" },
        { id = "stock", label = "Stock" },
        { id = "recipes", label = "Recipes" },
    }

    local x = 12
    for _, tab in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(100, 22)
        btn:SetPoint("TOPLEFT", x, -84)
        btn:SetText(tab.label)
        btn.tabId = tab.id
        btn:SetScript("OnClick", function()
            self:ShowTab(tab.id)
        end)
        f.tabButtons[tab.id] = btn
        x = x + 104
    end
end

function UI:UpdateOrdersLayout(tabId)
    local f = self.frame
    if not f or not f.queueInset then
        return
    end

    f.queueInset:ClearAllPoints()
    f.queueInset:SetPoint("TOPLEFT", 12, -108)
    f.queueInset:SetPoint("BOTTOMRIGHT", -12, 36)

    if tabId == "orders" then
        f.queueHeader:SetText("Order Queue")
        local room = GuildieCraftsTest_GetActiveRoom()
        if f.placeOrderBtn then
            if room and GuildieCraftsTest_IsWorkshopFullySupported(room) then
                f.placeOrderBtn:Show()
            else
                f.placeOrderBtn:Hide()
            end
        end
    elseif tabId == "completed" then
        f.queueHeader:SetText("Completed Orders")
        if f.placeOrderBtn then
            f.placeOrderBtn:Hide()
        end
    end

    self:LayoutQueuePanel()
end

function UI:LayoutQueuePanel()
    local f = self.frame
    if not f or not f.queueInset or not f.scroll then
        return
    end

    local inset = f.queueInset
    f.scroll:ClearAllPoints()
    f.scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", QUEUE_INSET_PADDING, -QUEUE_HEADER_BAND)
    f.scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, QUEUE_INSET_PADDING)

    if f.placeOrderBtn then
        f.placeOrderBtn:ClearAllPoints()
        f.placeOrderBtn:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -GetQueueRightInset(), -10)
        f.placeOrderBtn:SetFrameLevel(inset:GetFrameLevel() + 10)
    end

    if f.content then
        f.content:SetWidth(GetQueueContentWidth())
    end
end

function UI:UpdateTabAccess()
    local joined = GuildieCraftsTest_HasJoinedWorkshop()
    local f = self.frame
    if not f or not f.tabButtons then
        return
    end

    for _, tabId in ipairs({ "orders", "completed", "stock", "recipes" }) do
        local btn = f.tabButtons[tabId]
        if btn then
            if joined then
                btn:Enable()
            else
                btn:Disable()
            end
        end
    end

    if not joined and (self.activeTab == "orders" or self.activeTab == "completed" or self.activeTab == "stock" or self.activeTab == "recipes") then
        self.activeTab = "workshop"
        local f = self.frame
        if f then
            f.queueInset:Hide()
            if f.placeOrderBtn then f.placeOrderBtn:Hide() end
            self:CloseOrderDialog()
            if f.workshopPanel then f.workshopPanel:Show() end
            if f.stockPanel then f.stockPanel:Hide() end
            if f.recipesPanel then f.recipesPanel:Hide() end
            for id, btn in pairs(f.tabButtons or {}) do
                if id == "workshop" then btn:LockHighlight() else btn:UnlockHighlight() end
            end
        end
    end
end

function UI:ShowTab(tabId, skipAccessCheck)
    SafeCloseDropdownMenus()
    self:CloseOrderDialog()

    if not skipAccessCheck and (tabId == "orders" or tabId == "completed" or tabId == "stock" or tabId == "recipes") and not GuildieCraftsTest_HasJoinedWorkshop() then
        tabId = "workshop"
    end

    GuildieCraftsTest_ValidateActiveRoom()
    self.activeTab = tabId
    local f = self.frame

    local showOrders = tabId == "orders" or tabId == "completed"
    if showOrders then
        self:UpdateOrdersLayout(tabId)
    end
    f.queueInset:SetShown(showOrders)
    if f.workshopPanel then
        f.workshopPanel:SetShown(tabId == "workshop")
    end
    if f.stockPanel then
        f.stockPanel:SetShown(tabId == "stock")
    end
    if f.recipesPanel then
        f.recipesPanel:SetShown(tabId == "recipes")
    end

    for id, btn in pairs(f.tabButtons or {}) do
        if id == tabId then
            btn:LockHighlight()
        else
            btn:UnlockHighlight()
        end
    end

    if (tabId == "orders" or tabId == "completed" or tabId == "recipes") and GuildieCraftsTest_HasJoinedWorkshop() and IsInGuild() then
        GuildieCraftsTest.Sync:RequestSync()
    end

    if tabId == "workshop" and IsInGuild() then
        self._requestWorkshopSync = true
    end

    self:Refresh()
end

function UI:CreateWorkshopPanel()
    local f = self.frame
    local panel = CreateInsetPanel(f)
    panel:SetPoint("TOPLEFT", 12, -108)
    panel:SetPoint("BOTTOMRIGHT", -12, 36)
    panel:Hide()
    EnableDropdownDismissLayer(panel)

    panel.title = CreateLabel(panel, "Guildie Crafts", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -12)

    panel.status = CreateLabel(panel, "", "GameFontHighlight")
    panel.status:SetPoint("TOPLEFT", 16, -38)
    panel.status:SetWidth(FRAME_WIDTH - 48)
    panel.status:SetJustifyH("LEFT")

    panel.guildNotice = CreateLabel(panel, "", "GameFontHighlight")
    panel.guildNotice:SetPoint("TOPLEFT", panel.status, "BOTTOMLEFT", 0, -WORKSHOP_SECTION_GAP)
    panel.guildNotice:SetWidth(FRAME_WIDTH - 48)
    panel.guildNotice:SetJustifyH("LEFT")

    f.selectedCreateExpansion = GuildieCraftsTest_GetDefaultExpansion()
    f.selectedCreatePhase = GuildieCraftsTest_GetDefaultPhase()
    f.selectedCreateProfession = "jewelcrafting"

    panel.createSectionTitle = CreateLabel(panel, "Create new workshop", "GameFontNormal")
    panel.createSectionTitle:SetPoint("TOPLEFT", panel.guildNotice, "BOTTOMLEFT", 0, -WORKSHOP_SECTION_GAP)

    panel.createNameLabel = CreateLabel(panel, "Name:", "GameFontHighlight")
    panel.createNameLabel:SetPoint("TOPLEFT", panel.createSectionTitle, "BOTTOMLEFT", 0, -12)

    panel.nameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.nameInput:SetHeight(20)
    panel.nameInput:SetAutoFocus(false)
    panel.nameInput:SetMaxLetters(40)
    panel.nameInput:SetPoint("LEFT", panel, "LEFT", WORKSHOP_CONTROL_X, 0)
    panel.nameInput:SetPoint("TOP", panel.createNameLabel, "TOP", 0, WORKSHOP_CONTROL_V_OFFSET)
    panel.nameInput:SetWidth(WORKSHOP_DROPDOWN_WIDTH + 32)

    panel.createExpansionLabel = CreateLabel(panel, "Expansion:", "GameFontHighlight")
    panel.createExpansionLabel:SetPoint("TOPLEFT", panel.createNameLabel, "BOTTOMLEFT", 0, -WORKSHOP_FORM_ROW_GAP)

    panel.expansionDropdown = CreateFrame("Frame", "GuildieCraftsTestExpansionDropdown", panel, "UIDropDownMenuTemplate")
    panel.expansionDropdown:SetPoint("LEFT", panel.nameInput, "LEFT")
    panel.expansionDropdown:SetPoint("TOP", panel.createExpansionLabel, "TOP", 0, WORKSHOP_CONTROL_V_OFFSET)
    UIDropDownMenu_SetWidth(panel.expansionDropdown, WORKSHOP_DROPDOWN_WIDTH)
    UIDropDownMenu_Initialize(panel.expansionDropdown, function()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(GuildieCraftsTest_GetExpansionOptions()) do
            info = UIDropDownMenu_CreateInfo()
            local suffix = option.enabled and "" or " |cff888888(coming soon)|r"
            info.text = option.label .. suffix
            info.disabled = not option.enabled
            MarkDropdownSelection(info, f.selectedCreateExpansion == option.expansion)
            info.func = function()
                f.selectedCreateExpansion = option.expansion
                SetDropdownDisplayText(panel.expansionDropdown, option.label)
                UI:RefreshCreatePhaseDropdown()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    SetDropdownDisplayText(panel.expansionDropdown, "TBC")

    panel.createPhaseLabel = CreateLabel(panel, "Phase:", "GameFontHighlight")
    panel.createPhaseLabel:SetPoint("TOPLEFT", panel.createExpansionLabel, "BOTTOMLEFT", 0, -WORKSHOP_FORM_ROW_GAP)

    panel.phaseDropdown = CreateFrame("Frame", "GuildieCraftsTestPhaseDropdown", panel, "UIDropDownMenuTemplate")
    panel.phaseDropdown:SetPoint("LEFT", panel.expansionDropdown, "LEFT")
    panel.phaseDropdown:SetPoint("TOP", panel.createPhaseLabel, "TOP", 0, WORKSHOP_CONTROL_V_OFFSET)
    UIDropDownMenu_SetWidth(panel.phaseDropdown, WORKSHOP_DROPDOWN_WIDTH)
    UIDropDownMenu_Initialize(panel.phaseDropdown, function()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(GuildieCraftsTest_GetPhaseOptions(f.selectedCreateExpansion)) do
            info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            MarkDropdownSelection(info, f.selectedCreatePhase == option.phase)
            info.func = function()
                f.selectedCreatePhase = option.phase
                SetDropdownDisplayText(panel.phaseDropdown, option.label)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    SetDropdownDisplayText(panel.phaseDropdown, f.selectedCreatePhase)

    panel.createProfessionLabel = CreateLabel(panel, "Profession:", "GameFontHighlight")
    panel.createProfessionLabel:SetPoint("TOPLEFT", panel.createPhaseLabel, "BOTTOMLEFT", 0, -WORKSHOP_FORM_ROW_GAP)

    panel.professionDropdown = CreateFrame("Frame", "GuildieCraftsTestProfessionDropdown", panel, "UIDropDownMenuTemplate")
    panel.professionDropdown:SetPoint("LEFT", panel.expansionDropdown, "LEFT")
    panel.professionDropdown:SetPoint("TOP", panel.createProfessionLabel, "TOP", 0, WORKSHOP_CONTROL_V_OFFSET)
    UIDropDownMenu_SetWidth(panel.professionDropdown, WORKSHOP_DROPDOWN_WIDTH)
    UIDropDownMenu_Initialize(panel.professionDropdown, function()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        for _, profession in ipairs(GuildieCraftsTest_GetProfessionOptions()) do
            info = UIDropDownMenu_CreateInfo()
            local suffix = profession.enabled and "" or " |cff888888(unavailable)|r"
            info.text = profession.label .. suffix
            info.disabled = not profession.enabled
            MarkDropdownSelection(info, f.selectedCreateProfession == profession.id)
            info.func = function()
                f.selectedCreateProfession = profession.id
                SetDropdownDisplayText(panel.professionDropdown, profession.label)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    SetDropdownDisplayText(panel.professionDropdown, "Jewelcrafting")

    panel.createBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.createBtn:SetSize(90, 22)
    panel.createBtn:SetPoint("TOPLEFT", panel.professionDropdown, "BOTTOMLEFT", 0, -12)
    panel.createBtn:SetText("Create")
    panel.createBtn:SetScript("OnClick", function()
        local _, err = GuildieCraftsTest_CreateWorkshop(
            panel.nameInput:GetText(),
            f.selectedCreateExpansion,
            f.selectedCreatePhase,
            f.selectedCreateProfession
        )
        if err then
            print("|cff00ccffGuildieCraftsTest|r " .. err)
        else
            panel.nameInput:SetText("")
            print("|cff00ccffGuildieCraftsTest|r Workshop created.")
            self:Refresh()
        end
    end)

    panel.selectSectionTitle = CreateLabel(panel, "Select a workshop", "GameFontNormal")
    panel.selectSectionTitle:SetPoint("TOPLEFT", panel.createBtn, "BOTTOMLEFT", WORKSHOP_LABEL_X - WORKSHOP_CONTROL_X, -WORKSHOP_SECTION_GAP)

    panel.openLabel = CreateLabel(panel, "Workshop:", "GameFontHighlight")
    panel.openLabel:SetPoint("TOPLEFT", panel.selectSectionTitle, "BOTTOMLEFT", 0, -12)

    panel.joinDropdown = CreateFrame("Frame", "GuildieCraftsTestJoinDropdown", panel, "UIDropDownMenuTemplate")
    panel.joinDropdown:SetPoint("LEFT", panel.expansionDropdown, "LEFT")
    panel.joinDropdown:SetPoint("TOP", panel.openLabel, "TOP", 0, WORKSHOP_CONTROL_V_OFFSET)
    UIDropDownMenu_SetWidth(panel.joinDropdown, WORKSHOP_DROPDOWN_WIDTH)
    UIDropDownMenu_Initialize(panel.joinDropdown, function()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Select a workshop..."
        info.notCheckable = true
        info.disabled = true
        UIDropDownMenu_AddButton(info)

        for _, openRoom in ipairs(UI.joinRoomOptions or {}) do
            info = UIDropDownMenu_CreateInfo()
            info.text = string.format(
                "%s  |cff888888(%s)|r",
                openRoom.name,
                GuildieCraftsTest_FormatWorkshopScope(openRoom)
            )
            MarkDropdownSelection(info, GuildieCraftsTest_GetActiveRoomId() == openRoom.id)
            info.func = function()
                local _, err = GuildieCraftsTest_JoinWorkshop(openRoom.id)
                if err then
                    print("|cff00ccffGuildieCraftsTest|r " .. err)
                else
                    print("|cff00ccffGuildieCraftsTest|r Selected " .. openRoom.name .. ".")
                    SetDropdownDisplayText(panel.joinDropdown, openRoom.name)
                    UI:Refresh()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    panel.roomList = CreateLabel(panel, "", "GameFontHighlightSmall")
    panel.roomList:SetPoint("TOPLEFT", panel.joinDropdown, "BOTTOMLEFT", 0, -8)
    panel.roomList:SetWidth(FRAME_WIDTH - WORKSHOP_CONTROL_X - 32)
    panel.roomList:SetJustifyH("LEFT")

    panel.closeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.closeBtn:SetSize(120, 22)
    panel.closeBtn:SetPoint("TOPRIGHT", -16, -10)
    panel.closeBtn:SetText("Close workshop")
    panel.closeBtn:SetScript("OnClick", function()
        local room = GuildieCraftsTest_GetActiveRoom()
        if room then
            ConfirmCloseWorkshop(room)
        end
    end)

    panel.changeWorkshopBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.changeWorkshopBtn:SetSize(130, 22)
    panel.changeWorkshopBtn:SetPoint("RIGHT", panel.closeBtn, "LEFT", -8, 0)
    panel.changeWorkshopBtn:SetText("Change workshop")
    panel.changeWorkshopBtn:SetScript("OnClick", function()
        SafeCloseDropdownMenus()
        local _, err = GuildieCraftsTest_DeselectWorkshop()
        if err then
            print("|cff00ccffGuildieCraftsTest|r " .. err)
        else
            print("|cff00ccffGuildieCraftsTest|r Workshop deselected. You remain a member — select another below.")
            SetDropdownDisplayText(panel.joinDropdown, "Select a workshop...")
        end
        self:Refresh()
    end)

    panel.pickerControls = {
        panel.createSectionTitle,
        panel.createNameLabel,
        panel.nameInput,
        panel.createExpansionLabel,
        panel.expansionDropdown,
        panel.createPhaseLabel,
        panel.phaseDropdown,
        panel.createProfessionLabel,
        panel.professionDropdown,
        panel.createBtn,
        panel.selectSectionTitle,
        panel.openLabel,
        panel.joinDropdown,
    }

    panel.membersHelp = CreateLabel(panel, "Co-leaders can promote/demote crafters for all members except the leader. Only the leader manages co-leaders.", "GameFontDisableSmall")
    panel.membersHelp:SetWidth(FRAME_WIDTH - 48)
    panel.membersHelp:SetJustifyH("LEFT")
    panel.membersHelp:Hide()

    panel.membersLabel = CreateLabel(panel, "Members:", "GameFontHighlight")
    panel.membersLabel:SetPoint("TOPLEFT", 16, -240)

    local scroll = CreateFrame("ScrollFrame", "GuildieCraftsTestWorkshopMembersScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -258)
    scroll:SetPoint("BOTTOMRIGHT", -28, 36)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FRAME_WIDTH - 88, 200)
    scroll:SetScrollChild(content)

    panel.memberScroll = scroll
    panel.memberContent = content
    panel.memberRows = {}

    f.workshopPanel = panel
    self:RefreshCreatePhaseDropdown()
end

function UI:RefreshCreatePhaseDropdown()
    local f = self.frame
    local panel = f and f.workshopPanel
    if not panel or not panel.phaseDropdown then
        return
    end

    local phases = GuildieCraftsTest_GetPhaseOptions(f.selectedCreateExpansion)
    local valid = false
    for _, option in ipairs(phases) do
        if option.phase == f.selectedCreatePhase then
            valid = true
            break
        end
    end
    if not valid then
        f.selectedCreatePhase = phases[1] and phases[1].phase or nil
    end

    if f.selectedCreatePhase then
        SetDropdownDisplayText(panel.phaseDropdown, f.selectedCreatePhase)
        UIDropDownMenu_EnableDropDown(panel.phaseDropdown)
    else
        SetDropdownDisplayText(panel.phaseDropdown, "—")
        UIDropDownMenu_DisableDropDown(panel.phaseDropdown)
    end
end

function UI:LayoutWorkshopPanel(panel, showPicker)
    for _, control in ipairs(panel.pickerControls or {}) do
        control:SetShown(showPicker)
    end

    panel.guildNotice:ClearAllPoints()
    panel.guildNotice:SetPoint("TOPLEFT", panel.status, "BOTTOMLEFT", 0, -WORKSHOP_SECTION_GAP)

    panel.openLabel:ClearAllPoints()
    panel.roomList:ClearAllPoints()
    if showPicker then
        panel.openLabel:SetPoint("TOPLEFT", panel.selectSectionTitle, "BOTTOMLEFT", 0, -12)
        panel.openLabel:Show()
        panel.joinDropdown:ClearAllPoints()
        panel.joinDropdown:SetPoint("LEFT", panel.expansionDropdown, "LEFT")
        panel.joinDropdown:SetPoint("TOP", panel.openLabel, "TOP", 0, WORKSHOP_CONTROL_V_OFFSET)
        panel.roomList:SetPoint("TOPLEFT", panel.joinDropdown, "BOTTOMLEFT", 0, -8)
    else
        panel.openLabel:Hide()
        panel.roomList:Hide()
    end
end

function UI:ClearMemberRows()
    local panel = self.frame.workshopPanel
    if not panel then
        return
    end
    for _, row in ipairs(panel.memberRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    panel.memberRows = {}
end

function UI:RefreshWorkshopMembers()
    local panel = self.frame.workshopPanel
    if not panel then
        return
    end

    local room = GuildieCraftsTest_GetActiveRoom()
    panel.membersHelp:SetShown(room ~= nil)
    if room then
        local crafterPlural = GuildieCraftsTest_GetCrafterLabel(GuildieCraftsTest_GetRoomProfession(room))
        panel.membersHelp:SetText(string.format(
            "Co-leaders can promote/demote %s for all members except the leader. Only the leader manages co-leaders.",
            string.lower(crafterPlural)
        ))
    end
    panel.membersLabel:SetShown(room ~= nil)
    panel.memberScroll:SetShown(room ~= nil)

    self:ClearMemberRows()
    if not room then
        panel.memberContent:SetHeight(40)
        return
    end

    panel.membersHelp:ClearAllPoints()
    if panel.closeBtn:IsShown() then
        panel.membersHelp:SetPoint("TOPLEFT", panel.closeBtn, "BOTTOMLEFT", 0, -WORKSHOP_SECTION_GAP)
    elseif panel.changeWorkshopBtn:IsShown() then
        panel.membersHelp:SetPoint("TOPLEFT", panel.changeWorkshopBtn, "BOTTOMLEFT", 0, -WORKSHOP_SECTION_GAP)
    else
        panel.membersHelp:SetPoint("TOPLEFT", panel.status, "BOTTOMLEFT", 0, -WORKSHOP_SECTION_GAP)
    end

    panel.membersLabel:ClearAllPoints()
    panel.membersLabel:SetPoint("TOPLEFT", panel.membersHelp, "BOTTOMLEFT", 0, -WORKSHOP_MEMBERS_GAP)
    panel.memberScroll:ClearAllPoints()
    panel.memberScroll:SetPoint("TOPLEFT", panel.membersLabel, "BOTTOMLEFT", -4, -8)
    panel.memberScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 36)

    local player = UnitName("player")
    local isManager = GuildieCraftsTest_CanManageWorkshop(room, player)
    local isOwner = GuildieCraftsTest_IsWorkshopOwner(room, player)
    local members = GuildieCraftsTest_GetSortedRoomMembers(room)
    local crafterSingular = GuildieCraftsTest_GetRoomCrafterSingular(room)
    local crafterShort = GuildieCraftsTest_GetRoomCrafterShortLabel(room)
    local y = 0
    for _, name in ipairs(members) do
        local row = CreateFrame("Frame", nil, panel.memberContent)
        row:SetSize(FRAME_WIDTH - 88, 28)
        row:SetPoint("TOPLEFT", 0, -y)

        local label = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", 8, 0)
        label:SetWidth(FRAME_WIDTH - 320)
        label:SetJustifyH("LEFT")
        local tags = {}
        if name == room.leader then
            table.insert(tags, "|cff00ff00Leader|r")
        end
        if room.coLeaders and room.coLeaders[name] then
            table.insert(tags, "|cffffcc00Co-leader|r")
        end
        if room.collaborators and room.collaborators[name] then
            table.insert(tags, "|cff66ccff" .. crafterSingular .. "|r")
        end
        local tagText = #tags > 0 and ("  " .. table.concat(tags, " ")) or ""
        label:SetText(GuildieCraftsTest_ColorizePlayer(name) .. tagText)

        local isSelf = name == player
        local isLeaderRow = name == room.leader
        local isTargetCoLeader = room.coLeaders and room.coLeaders[name]
        local isJewelcrafter = room.collaborators and room.collaborators[name]
        local canManageJC = isManager and ((isLeaderRow and isSelf) or not isLeaderRow)
        local canManageCoLeader = isOwner and not isLeaderRow

        if canManageJC or canManageCoLeader then
            local right = -8
            local function placeBtn(text, onClick)
                local measure = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                measure:SetText(text)
                local width = math.max(88, math.ceil(measure:GetStringWidth()) + 20)
                measure:Hide()
                measure:SetParent(nil)

                local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                btn:SetSize(width, 22)
                btn:SetPoint("RIGHT", right, 0)
                btn:SetText(text)
                btn:SetScript("OnClick", onClick)
                right = right - width - 4
            end

            if canManageCoLeader and not isTargetCoLeader then
                placeBtn("Make co-leader", function()
                    local ok, err = GuildieCraftsTest_AddCoLeader(room.id, name)
                    if not ok then
                        print("|cff00ccffGuildieCraftsTest|r " .. (err or "Action failed."))
                    else
                        self:Refresh()
                    end
                end)
            end

            if canManageJC then
                if isJewelcrafter then
                    placeBtn("Demote " .. crafterShort, function()
                        local ok, err = GuildieCraftsTest_DemoteCollaborator(room.id, name)
                        if not ok then
                            print("|cff00ccffGuildieCraftsTest|r " .. (err or "Action failed."))
                        else
                            self._requestWorkshopSync = false
                            self:Refresh()
                        end
                    end)
                else
                    placeBtn("Make " .. crafterShort, function()
                        local ok, err = GuildieCraftsTest_PromoteMember(room.id, name)
                        if not ok then
                            print("|cff00ccffGuildieCraftsTest|r " .. (err or "Action failed."))
                        else
                            self._requestWorkshopSync = false
                            self:Refresh()
                        end
                    end)
                end
            end

            if canManageCoLeader and isTargetCoLeader then
                placeBtn("Demote co-leader", function()
                    local ok, err = GuildieCraftsTest_RemoveCoLeader(room.id, name)
                    if not ok then
                        print("|cff00ccffGuildieCraftsTest|r " .. (err or "Action failed."))
                    else
                        self:Refresh()
                    end
                end)
            end
        end

        table.insert(panel.memberRows, row)
        y = y + 30
    end
    panel.memberContent:SetHeight(math.max(80, y + 8))
end

function UI:RefreshWorkshopPanel()
    local panel = self.frame.workshopPanel
    if not panel then
        return
    end

    self:RefreshJoinDropdownCache()
    if IsInGuild() and self._requestWorkshopSync then
        self._requestWorkshopSync = false
        GuildieCraftsTest.Sync:RequestSync()
    end

    local inGuild = IsInGuild()
    if inGuild then
        panel.createBtn:Enable()
        panel.nameInput:Enable()
        UIDropDownMenu_EnableDropDown(panel.expansionDropdown)
        UIDropDownMenu_EnableDropDown(panel.professionDropdown)
        self:RefreshCreatePhaseDropdown()
    else
        panel.createBtn:Disable()
        panel.nameInput:Disable()
        UIDropDownMenu_DisableDropDown(panel.expansionDropdown)
        UIDropDownMenu_DisableDropDown(panel.phaseDropdown)
        UIDropDownMenu_DisableDropDown(panel.professionDropdown)
    end

    local room = GuildieCraftsTest_GetActiveRoom()
    local showPicker = room == nil
    self:LayoutWorkshopPanel(panel, showPicker)

    if room then
        panel.guildNotice:Hide()
        panel.status:SetText(string.format(
            "Active: |cff00ff00%s|r  |cff888888(%s)|r",
            room.name,
            GuildieCraftsTest_FormatWorkshopScope(room)
        ))
    else
        panel.status:SetText("|cff888888No workshop selected — select or create one to place orders.|r")
        if inGuild then
            panel.guildNotice:SetText("|cff888888Guild-only — workshops are never shared outside your guild.|r")
            panel.guildNotice:Show()
        else
            panel.guildNotice:SetText("|cffff0000You must be in a guild to create or select workshops.|r")
            panel.guildNotice:Show()
        end
    end

    if room then
        panel.roomList:SetText("")
        panel.roomList:Hide()
    elseif #GuildieCraftsTest_GetOpenRooms() == 0 then
        panel.roomList:Show()
        panel.roomList:SetText("No open workshops yet.")
    else
        panel.roomList:Show()
        panel.roomList:SetText("")
    end

    if room then
        SetDropdownDisplayText(panel.joinDropdown, room.name)
    else
        SetDropdownDisplayText(panel.joinDropdown, "Select a workshop...")
    end

    local canManageWorkshop = room and GuildieCraftsTest_CanManageWorkshop(room, UnitName("player"))

    panel.title:SetShown(not room)
    panel.status:ClearAllPoints()
    if room then
        panel.status:SetPoint("TOPLEFT", 16, -12)
    else
        panel.status:SetPoint("TOPLEFT", 16, -38)
    end
    panel.status:SetWidth(FRAME_WIDTH - 48)

    panel.changeWorkshopBtn:ClearAllPoints()
    panel.closeBtn:ClearAllPoints()
    if room then
        panel.changeWorkshopBtn:SetPoint("TOPLEFT", panel.status, "BOTTOMLEFT", 0, -10)
        panel.changeWorkshopBtn:Show()
        if canManageWorkshop then
            panel.closeBtn:SetPoint("LEFT", panel.changeWorkshopBtn, "RIGHT", 8, 0)
            panel.closeBtn:Show()
        else
            panel.closeBtn:Hide()
        end
    else
        panel.changeWorkshopBtn:Hide()
        panel.closeBtn:Hide()
    end

    self:RefreshWorkshopMembers()
end

function UI:CreateStockPanel()
    local f = self.frame
    local panel = CreateInsetPanel(f)
    panel:SetPoint("TOPLEFT", 12, -108)
    panel:SetPoint("BOTTOMRIGHT", -12, 36)
    panel:Hide()
    ApplyParchmentBackground(panel)
    EnableDropdownDismissLayer(panel)

    panel.title = CreateLabel(panel, "Material Stock", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -12)

    panel.refreshBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.refreshBtn:SetSize(100, 22)
    panel.refreshBtn:SetPoint("TOPRIGHT", -16, -10)
    panel.refreshBtn:SetText("Refresh")
    panel.refreshBtn:SetScript("OnClick", function()
        local room = GuildieCraftsTest_GetActiveRoom()
        if room and not GuildieCraftsTest_IsWorkshopFullySupported(room) then
            print("|cff00ccffGuildieCraftsTest|r " .. GuildieCraftsTest_GetUnsupportedWorkshopMessage(room))
            return
        end
        if GuildieCraftsTest_ShouldShareStock() then
            GuildieCraftsTest_RefreshLocalStock()
            print("|cff00ccffGuildieCraftsTest|r Material stock scanned and shared with the workshop.")
        elseif GuildieCraftsTest.UI then
            GuildieCraftsTest_RefreshUI()
            print("|cff00ccffGuildieCraftsTest|r Material stock refreshed.")
        end
    end)

    local scroll = CreateFrame("ScrollFrame", "GuildieCraftsTestStockScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -40)
    scroll:SetPoint("BOTTOMRIGHT", -28, 12)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FRAME_WIDTH - 88, 600)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    panel.stockLines = {}

    f.stockPanel = panel
end

function UI:ClearStockRows()
    local panel = self.frame.stockPanel
    if not panel then
        return
    end
    for _, row in ipairs(panel.stockLines or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    panel.stockLines = {}
end

function UI:RefreshStockPanel()
    local panel = self.frame.stockPanel
    if not panel then
        return
    end

    self:ClearStockRows()
    panel.stockLines = panel.stockLines or {}
    local parent = panel.content
    local y = 0

    local room = GuildieCraftsTest_GetActiveRoom()
    if not room then
        panel.title:SetText("Material Stock")
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetText("Select a workshop to view collaborator stock.")
        table.insert(panel.stockLines, empty)
        panel.content:SetHeight(80)
        return
    end

    if not GuildieCraftsTest_IsWorkshopFullySupported(room) then
        panel.title:SetText("Material Stock")
        panel.refreshBtn:Disable()
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetWidth(FRAME_WIDTH - 88)
        empty:SetJustifyH("LEFT")
        empty:SetText(GuildieCraftsTest_GetUnsupportedWorkshopMessage(room))
        table.insert(panel.stockLines, empty)
        panel.content:SetHeight(80)
        return
    end

    panel.title:SetText(GuildieCraftsTest_IsJewelcraftingWorkshop(room) and "Gem Stock Overview"
        or (GuildieCraftsTest_GetRoomScarceMaterialName(room) or "Material") .. " Stock")
    panel.refreshBtn:Enable()

    local crafterSingular = GuildieCraftsTest_GetRoomCrafterSingular(room)
    local crafterPlural = GuildieCraftsTest_GetCrafterLabel(GuildieCraftsTest_GetRoomProfession(room))

    local function AddDivider()
        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 12, -y)
        line:SetPoint("TOPRIGHT", -12, -y)
        line:SetColorTexture(0.45, 0.38, 0.28, 0.65)
        table.insert(panel.stockLines, line)
        y = y + 10
    end

    local function AddGemLines(counts, indent)
        indent = indent or 16
        local listing = GuildieCraftsTest_GetStockListing(counts, GuildieCraftsTest_GetRoomProfession(room))
        if #listing == 0 then
            local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
            empty:SetPoint("TOPLEFT", indent, -y)
            empty:SetText("No tracked materials found.")
            table.insert(panel.stockLines, empty)
            y = y + 18
            return
        end

        for _, entry in ipairs(listing) do
            local row = CreateFrame("Button", nil, parent)
            row:SetPoint("TOPLEFT", indent, -y)
            row:SetSize(320, 16)
            local line = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            line:SetPoint("LEFT", 0, 0)
            line:SetJustifyH("LEFT")
            line:SetText(string.format("%dx %s", entry.count, ColorizeGem(entry.name)))
            row:SetWidth(line:GetStringWidth() + 4)
            if entry.itemId then
                GuildieCraftsTest_AttachItemTooltip(row, function()
                    return entry.itemId
                end)
            end
            table.insert(panel.stockLines, row)
            y = y + 16
        end
    end

    local function AddSection(title, counts, style, opts)
        style = style or "personal"
        opts = opts or {}

        if style == "total" then
            AddDivider()
            y = y + 4
        elseif style == "jc" then
            AddDivider()
        end

        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        if style == "total" then
            header:SetFontObject("GameFontNormalLarge")
            header:SetText("|cff00ff00" .. title .. "|r")
        elseif style == "jc" then
            header:SetFontObject("GameFontHighlightSmall")
            local nameText = GuildieCraftsTest_ColorizePlayer(title)
            if opts.noReport then
                nameText = nameText .. " |cff888888(no report yet)|r"
            end
            header:SetText("|cff66ccff" .. crafterSingular .. "|r — " .. nameText)
        elseif style == "group" then
            header:SetFontObject("GameFontHighlight")
            header:SetText(title)
        else
            header:SetFontObject("GameFontHighlight")
            header:SetText(title)
        end

        header:SetPoint("TOPLEFT", 8, -y)
        table.insert(panel.stockLines, header)
        y = y + (style == "total" and 26 or 20)

        if style == "group" then
            y = y + 4
            return
        end

        AddGemLines(counts, style == "jc" and 24 or 16)
        y = y + 8
    end

    local player = UnitName("player")
    local canShare = GuildieCraftsTest_ShouldShareStock()
    if canShare then
        local personalTitle = "Your Bags + Bank"
        local bankNote = GuildieCraftsTest_GetBankStockNote and GuildieCraftsTest_GetBankStockNote()
        if bankNote then
            personalTitle = personalTitle .. " |cff888888(" .. bankNote .. ")|r"
        end
        AddSection(personalTitle, GuildieCraftsTest_GetStockCounts("personal"), "personal")
    end

    local sharedJcs = {}
    for _, jcName in ipairs(GuildieCraftsTest_GetWorkshopStockContributors(room)) do
        if not (canShare and jcName == player) then
            table.insert(sharedJcs, jcName)
        end
    end

    if #sharedJcs > 0 then
        AddSection("Shared by " .. crafterPlural, {}, "group")
        for _, jcName in ipairs(sharedJcs) do
            local report = GuildieCraftsTestDB.stock.jcReports[jcName]
            local counts = report and report.counts or {}
            AddSection(jcName, counts, "jc", { noReport = not report })
        end
    end

    AddSection("Workshop Total", GuildieCraftsTest_GetAggregatedWorkshopStock(room), "total")

    panel.content:SetHeight(math.max(400, y + 20))
end

function UI:CreateRecipesPanel()
    if GuildieCraftsTest_InitRecipeEvents then
        GuildieCraftsTest_InitRecipeEvents()
    end
    local f = self.frame
    local panel = CreateInsetPanel(f)
    panel:SetPoint("TOPLEFT", 12, -108)
    panel:SetPoint("BOTTOMRIGHT", -12, 36)
    panel:Hide()
    ApplyParchmentBackground(panel)
    EnableDropdownDismissLayer(panel)

    panel.title = CreateLabel(panel, "Workshop Recipes", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -16)

    panel.help = CreateLabel(panel, "Phase 3 epic gem cuts known by promoted jewelcrafters.", "GameFontDisableSmall")
    panel.help:SetPoint("TOPLEFT", 16, -42)
    panel.help:SetWidth(FRAME_WIDTH - 140)
    panel.help:SetJustifyH("LEFT")

    panel.recipeSubTab = "epic"
    panel.subTabButtons = {}
    local subTabs = {
        { id = "epic", label = "Epic" },
        { id = "rare", label = "Rare" },
    }
    local subX = 16
    for _, subTab in ipairs(subTabs) do
        local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        btn:SetSize(72, 22)
        btn:SetPoint("TOPLEFT", subX, -88)
        btn:SetText(subTab.label)
        btn.subTabId = subTab.id
        btn:SetScript("OnClick", function()
            panel.recipeSubTab = subTab.id
            for _, other in ipairs(panel.subTabButtons) do
                if other.subTabId == subTab.id then
                    other:LockHighlight()
                else
                    other:UnlockHighlight()
                end
            end
            panel.help:SetText(subTab.id == "rare"
                and "Rare gem cuts from Living Ruby, Star of Elune, Nightseye, Talasite, Noble Topaz, and Dawnstone."
                or "Phase 3 epic gem cuts known by promoted jewelcrafters.")
            self:RefreshRecipesPanel()
        end)
        table.insert(panel.subTabButtons, btn)
        subX = subX + 80
        if subTab.id == "epic" then
            btn:LockHighlight()
        end
    end

    panel.refreshBtn = CreateFrame("Button", "GuildieCraftsTestRecipesRefresh", panel, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    panel.refreshBtn:SetSize(100, 22)
    panel.refreshBtn:SetPoint("TOPRIGHT", -16, -14)
    panel.refreshBtn:SetText("Refresh")
    panel.refreshBtn:SetScript("OnShow", function(self)
        if GuildieCraftsTest_InitRecipesRefreshButton then
            GuildieCraftsTest_InitRecipesRefreshButton(self)
        end
    end)

    local scroll = CreateFrame("ScrollFrame", "GuildieCraftsTestRecipesScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -118)
    scroll:SetPoint("BOTTOMRIGHT", -28, 12)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FRAME_WIDTH - 88, 600)
    scroll:SetScrollChild(content)

    panel.scroll = scroll
    panel.content = content
    panel.recipeLines = {}

    f.recipesPanel = panel
end

function UI:ClearRecipeRows()
    local panel = self.frame.recipesPanel
    if not panel then
        return
    end
    for _, row in ipairs(panel.recipeLines or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    panel.recipeLines = {}
end

function UI:RefreshRecipesPanel()
    local panel = self.frame.recipesPanel
    if not panel then
        return
    end

    self:ClearRecipeRows()
    panel.recipeLines = panel.recipeLines or {}
    local parent = panel.content

    local room = GuildieCraftsTest_GetActiveRoom()
    if not room then
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetText("Select a workshop to view recipe coverage.")
        table.insert(panel.recipeLines, empty)
        panel.content:SetHeight(80)
        return
    end

    if not GuildieCraftsTest_IsWorkshopFullySupported(room) then
        panel.refreshBtn:Disable()
        panel.help:SetText(GuildieCraftsTest_GetUnsupportedWorkshopMessage(room))
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetWidth(FRAME_WIDTH - 88)
        empty:SetJustifyH("LEFT")
        empty:SetText(GuildieCraftsTest_GetUnsupportedWorkshopMessage(room))
        table.insert(panel.recipeLines, empty)
        panel.content:SetHeight(80)
        return
    end

    panel.refreshBtn:Enable()
    local isJewelcrafting = GuildieCraftsTest_IsJewelcraftingWorkshop(room)
    for _, btn in ipairs(panel.subTabButtons or {}) do
        btn:SetShown(isJewelcrafting)
    end
    if isJewelcrafting then
        local tier = panel.recipeSubTab or "epic"
        panel.help:SetText(tier == "rare"
            and "Rare gem cuts from Living Ruby, Star of Elune, Nightseye, Talasite, Noble Topaz, and Dawnstone."
            or "Phase 3 epic gem cuts known by promoted jewelcrafters.")
    else
        panel.help:SetText("Phase 3 Heart of Darkness crafts known by promoted "
            .. string.lower(GuildieCraftsTest_GetCrafterLabel(GuildieCraftsTest_GetRoomProfession(room))) .. ".")
    end

    local contributors = GuildieCraftsTest_GetWorkshopStockContributors(room)
    local crafterPlural = GuildieCraftsTest_GetCrafterLabel(GuildieCraftsTest_GetRoomProfession(room))
    if #contributors == 0 then
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetText("No promoted " .. string.lower(crafterPlural) .. " in this workshop yet.")
        table.insert(panel.recipeLines, empty)
        panel.content:SetHeight(80)
        return
    end

    local currentColor = nil
    local currentCategory = nil
    local tier = panel.recipeSubTab or "epic"
    local y = 8
    for _, entry in ipairs(GuildieCraftsTest_GetRecipeCoverage(room, tier)) do
        if entry.craft then
            local craft = entry.craft
            if craft.category ~= currentCategory then
                if currentCategory then
                    y = y + RECIPE_SECTION_GAP
                end
                currentCategory = craft.category
                local header = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                header:SetPoint("TOPLEFT", 8, -y)
                header:SetText(currentCategory)
                table.insert(panel.recipeLines, header)
                y = y + 18 + RECIPE_HEADER_AFTER_GAP
            end

            local row = CreateFrame("Frame", nil, parent)
            row:SetSize(FRAME_WIDTH - 88, RECIPE_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, -y)

            local hasRecipe = #entry.jcs > 0
            local nameBtn = CreateFrame("Button", nil, row)
            nameBtn:SetPoint("LEFT", 8, 0)
            nameBtn:SetSize(260, 18)
            local nameText = nameBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", 0, 0)
            nameText:SetText(hasRecipe and ColorizeItem(craft.name) or ("|cff888888" .. craft.name .. "|r"))
            GuildieCraftsTest_AttachItemTooltip(nameBtn, function()
                return craft.itemId
            end)

            local crafterLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            crafterLabel:SetPoint("LEFT", nameBtn, "RIGHT", 8, 0)
            crafterLabel:SetPoint("RIGHT", -8, 0)
            crafterLabel:SetJustifyH("RIGHT")
            if hasRecipe then
                local names = {}
                for _, crafterName in ipairs(entry.jcs) do
                    table.insert(names, GuildieCraftsTest_ColorizePlayer(crafterName))
                end
                crafterLabel:SetText(table.concat(names, ", "))
            else
                crafterLabel:SetText("|cff888888—|r")
            end

            table.insert(panel.recipeLines, row)
            y = y + RECIPE_ROW_HEIGHT
        else
            local gem = entry.gem
            if gem.color ~= currentColor then
                if currentColor then
                    y = y + RECIPE_SECTION_GAP
                end
                currentColor = gem.color
                local header = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                header:SetPoint("TOPLEFT", 8, -y)
                header:SetText(currentColor .. " gems")
                table.insert(panel.recipeLines, header)
                y = y + 18 + RECIPE_HEADER_AFTER_GAP
            end

            local row = CreateFrame("Frame", nil, parent)
            row:SetSize(FRAME_WIDTH - 88, RECIPE_ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, -y)

            local hasRecipe = #entry.jcs > 0
            local nameBtn = CreateFrame("Button", nil, row)
            nameBtn:SetPoint("LEFT", 8, 0)
            nameBtn:SetSize(260, 18)
            local nameText = nameBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            nameText:SetPoint("LEFT", 0, 0)
            nameText:SetText(hasRecipe and ColorizeGem(gem.name) or GreyGem(gem.name))
            GuildieCraftsTest_AttachItemTooltip(nameBtn, function()
                return gem.itemId
            end)

            local jcLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            jcLabel:SetPoint("LEFT", nameBtn, "RIGHT", 8, 0)
            jcLabel:SetPoint("RIGHT", -8, 0)
            jcLabel:SetJustifyH("RIGHT")
            if hasRecipe then
                local names = {}
                for _, jcName in ipairs(entry.jcs) do
                    table.insert(names, GuildieCraftsTest_ColorizePlayer(jcName))
                end
                jcLabel:SetText(table.concat(names, ", "))
            else
                jcLabel:SetText("|cff888888—|r")
            end

            table.insert(panel.recipeLines, row)
            y = y + RECIPE_ROW_HEIGHT
        end
    end

    panel.content:SetHeight(math.max(400, y + 24))
end

function UI:ClearGearItemSelection(frameRef)
    frameRef.selectedGear = nil
    if frameRef.gearDropdown then
        SetDropdownDisplayText(frameRef.gearDropdown, "Select gear...")
    end
end

function UI:PopulateGearDropdown(dropdown, frameRef)
    self:BuildDropdownCaches()
    GuildieCraftsTest_ClearDropdownItemTooltips()
    local buttonIndex = 0
    local indexToItemId = {}
    local category = frameRef.selectedGearCategory

    local clearInfo = UIDropDownMenu_CreateInfo()
    clearInfo.text = "Select gear..."
    clearInfo.value = 0
    MarkDropdownSelection(clearInfo, not frameRef.selectedGear)
    clearInfo.func = function()
        self:ClearGearItemSelection(frameRef)
    end
    UIDropDownMenu_AddButton(clearInfo)
    buttonIndex = buttonIndex + 1

    if not category then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Choose PVE or PVP first"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)
        GuildieCraftsTest_ApplyDropdownItemTooltips(indexToItemId)
        return
    end

    if category == "PVE" then
        for _, raid in ipairs(GuildieCraftsTest_GearRaids) do
            local header = UIDropDownMenu_CreateInfo()
            header.text = raid
            header.isTitle = true
            header.notCheckable = true
            UIDropDownMenu_AddButton(header)
            buttonIndex = buttonIndex + 1

            for _, gear in ipairs(GuildieCraftsTest_GetGearByRaid(raid)) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = gear.label
                info.value = gear.itemId
                MarkDropdownSelection(info, frameRef.selectedGear and frameRef.selectedGear.itemId == gear.itemId)
                info.func = function()
                    SetDropdownDisplayText(dropdown, gear.name)
                    frameRef.selectedGear = gear
                end
                UIDropDownMenu_AddButton(info)
                buttonIndex = buttonIndex + 1
                indexToItemId[buttonIndex] = gear.itemId
            end
        end
    else
        local className = frameRef.selectedGearClass
        if not className then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Choose a class first"
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info)
            GuildieCraftsTest_ApplyDropdownItemTooltips(indexToItemId)
            return
        end

        for _, gear in ipairs(GuildieCraftsTest_GetGearByClass(className)) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = gear.label
            info.value = gear.itemId
            MarkDropdownSelection(info, frameRef.selectedGear and frameRef.selectedGear.itemId == gear.itemId)
            info.func = function()
                SetDropdownDisplayText(dropdown, gear.name)
                frameRef.selectedGear = gear
            end
            UIDropDownMenu_AddButton(info)
            buttonIndex = buttonIndex + 1
            indexToItemId[buttonIndex] = gear.itemId
        end
    end

    GuildieCraftsTest_ApplyDropdownItemTooltips(indexToItemId)
end

function UI:CreateGearDropdown(name, parent, point, x, y, frameRef, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, parent, point, x, y)

    UIDropDownMenu_SetWidth(dropdown, width or 300)
    UIDropDownMenu_Initialize(dropdown, function()
        self:PopulateGearDropdown(dropdown, frameRef)
    end)

    SetDropdownDisplayText(dropdown, "Select gear...")
    GuildieCraftsTest_AttachDropdownTooltips(dropdown, function()
        return frameRef.selectedGear and frameRef.selectedGear.itemId
    end)
    ConfigureOrderDropdown(dropdown, width)
    return dropdown
end

function UI:CreateGearTypeDropdown(name, parent, point, x, y, frameRef, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, parent, point, x, y)
    UIDropDownMenu_SetWidth(dropdown, width or 300)

    UIDropDownMenu_Initialize(dropdown, function()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local clearInfo = UIDropDownMenu_CreateInfo()
        clearInfo.text = GEAR_TYPE_PLACEHOLDER
        MarkDropdownSelection(clearInfo, not frameRef.selectedGearCategory)
        clearInfo.func = function()
            frameRef.selectedGearCategory = nil
            frameRef.selectedGearClass = nil
            SetDropdownDisplayText(dropdown, GEAR_TYPE_PLACEHOLDER)
            SetDropdownDisplayText(frameRef.gearClassDropdown, GEAR_CLASS_PLACEHOLDER)
            self:ClearGearItemSelection(frameRef)
            if frameRef.gearClassLabel then
                frameRef.gearClassLabel:Hide()
            end
            if frameRef.gearClassDropdown then
                frameRef.gearClassDropdown:Hide()
            end
            self:RelayoutOrderForm()
        end
        UIDropDownMenu_AddButton(clearInfo)

        for _, category in ipairs(GuildieCraftsTest_GearCategories) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = category
            MarkDropdownSelection(info, frameRef.selectedGearCategory == category)
            info.func = function()
                frameRef.selectedGearCategory = category
                frameRef.selectedGearClass = nil
                SetDropdownDisplayText(dropdown, category)
                SetDropdownDisplayText(frameRef.gearClassDropdown, GEAR_CLASS_PLACEHOLDER)
                self:ClearGearItemSelection(frameRef)
                if category == "PVP" then
                    if frameRef.gearClassLabel then
                        frameRef.gearClassLabel:Show()
                    end
                    if frameRef.gearClassDropdown then
                        frameRef.gearClassDropdown:Show()
                    end
                else
                    if frameRef.gearClassLabel then
                        frameRef.gearClassLabel:Hide()
                    end
                    if frameRef.gearClassDropdown then
                        frameRef.gearClassDropdown:Hide()
                    end
                end
                self:RelayoutOrderForm()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    SetDropdownDisplayText(dropdown, GEAR_TYPE_PLACEHOLDER)
    ConfigureOrderDropdown(dropdown, width)
    return dropdown
end

function UI:CreateGearClassDropdown(name, parent, point, x, y, frameRef, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, parent, point, x, y)
    UIDropDownMenu_SetWidth(dropdown, width or 300)
    dropdown:Hide()

    UIDropDownMenu_Initialize(dropdown, function()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local clearInfo = UIDropDownMenu_CreateInfo()
        clearInfo.text = GEAR_CLASS_PLACEHOLDER
        MarkDropdownSelection(clearInfo, not frameRef.selectedGearClass)
        clearInfo.func = function()
            frameRef.selectedGearClass = nil
            SetDropdownDisplayText(dropdown, GEAR_CLASS_PLACEHOLDER)
            self:ClearGearItemSelection(frameRef)
        end
        UIDropDownMenu_AddButton(clearInfo)

        for _, className in ipairs(GuildieCraftsTest_PvpClasses) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = className
            MarkDropdownSelection(info, frameRef.selectedGearClass == className)
            info.func = function()
                frameRef.selectedGearClass = className
                SetDropdownDisplayText(dropdown, className)
                self:ClearGearItemSelection(frameRef)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    SetDropdownDisplayText(dropdown, GEAR_CLASS_PLACEHOLDER)
    ConfigureOrderDropdown(dropdown, width)
    return dropdown
end

function UI:CreateGemDropdown(name, parent, point, x, y, onSelect, getSelected, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, parent, point, x, y)

    UIDropDownMenu_SetWidth(dropdown, width or 240)
    UIDropDownMenu_Initialize(dropdown, function()
        self:BuildDropdownCaches()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local buttonIndex = 0
        local indexToItemId = {}

        for _, entry in ipairs(self.gemMenuEntries) do
            local info = UIDropDownMenu_CreateInfo()
            if entry.kind == "none" then
                info.text = GEM_PLACEHOLDER
                info.value = 0
                MarkDropdownSelection(info, getSelected() == "None")
                info.func = function()
                    SetDropdownDisplayText(dropdown, GEM_PLACEHOLDER)
                    onSelect("None")
                end
            elseif entry.kind == "header" then
                info.text = entry.text
                info.isTitle = true
                info.notCheckable = true
            elseif entry.kind == "gem" then
                local gem = entry.gem
                local label = GuildieCraftsTest_FormatGemDropdownLabel(gem.name) or gem.name
                info.text = label
                info.value = gem.itemId
                MarkDropdownSelection(info, getSelected() == gem.name)
                info.func = function()
                    SetDropdownDisplayText(dropdown, label)
                    onSelect(gem.name)
                end
            end
            UIDropDownMenu_AddButton(info)
            buttonIndex = buttonIndex + 1
            if entry.kind == "gem" then
                indexToItemId[buttonIndex] = entry.gem.itemId
            end
        end

        GuildieCraftsTest_ApplyDropdownItemTooltips(indexToItemId)
    end)

    SetDropdownDisplayText(dropdown, GEM_PLACEHOLDER)
    GuildieCraftsTest_AttachDropdownTooltips(dropdown, function()
        return GuildieCraftsTest_GetGemItemId(getSelected())
    end)
    ConfigureOrderDropdown(dropdown, width)
    return dropdown
end

function UI:RefreshGemDropdownLabels()
    local f = self.frame
    if not f or not f.gemDropdowns then
        return
    end

    for i = 1, 3 do
        local dropdown = f.gemDropdowns[i]
        local gemName = f.selectedGems and f.selectedGems[i]
        if dropdown and gemName and gemName ~= "None" then
            SetDropdownDisplayText(dropdown, GuildieCraftsTest_FormatGemDropdownLabel(gemName) or gemName)
        end
    end
end

function UI:UpdateOrderDialogPortrait(_room)
end

function UI:ConfigureOrderFormMode(room)
    local f = self.frame
    if not f then
        return
    end

    local isCraft = room and GuildieCraftsTest_IsHoDProfession(GuildieCraftsTest_GetRoomProfession(room))
    f.orderFormMode = isCraft and "craft" or "jc"

    local function setShown(widget, shown)
        if widget then
            if shown then
                widget:Show()
            else
                widget:Hide()
            end
        end
    end

    setShown(f.gearTypeLabel, not isCraft)
    setShown(f.gearTypeDropdown, not isCraft)
    setShown(f.gearClassLabel, not isCraft and f.selectedGearCategory == "PVP")
    setShown(f.gearClassDropdown, not isCraft and f.selectedGearCategory == "PVP")
    setShown(f.itemLabel, not isCraft)
    setShown(f.gearDropdown, not isCraft)

    for i = 1, 3 do
        setShown(f.gemLabels and f.gemLabels[i], not isCraft)
        setShown(f.gemDropdowns and f.gemDropdowns[i], not isCraft)
        if f.gemWarnings and f.gemWarnings[i] then
            f.gemWarnings[i]:Hide()
        end
    end

    setShown(f.craftCategoryLabel, isCraft)
    setShown(f.craftCategoryDropdown, isCraft)
    setShown(f.craftLabel, isCraft)
    setShown(f.craftDropdown, isCraft)
    setShown(f.craftWarning, isCraft and f.craftWarning and f.craftWarning:IsShown())
    setShown(f.materialsAckCheck, isCraft)

    if not isCraft and f.materialsAckCheck then
        f.materialsAckCheck:SetChecked(false)
    end

    if isCraft then
        f.selectedGearCategory = nil
        f.selectedGearClass = nil
        f.selectedGear = nil
        if f.craftCategoryDropdown then
            SetDropdownDisplayText(
                f.craftCategoryDropdown,
                f.selectedCraftCategory or CRAFT_CATEGORY_PLACEHOLDER
            )
        end
        if f.craftDropdown then
            self:PopulateCraftDropdown(f.craftDropdown, f)
        end
    else
        f.selectedCraftCategory = nil
        f.selectedCraft = nil
    end

    self:RelayoutOrderForm()
    self:UpdateOrderSubmitState()
    self:UpdateOrderDialogPortrait(room)
end

function UI:UpdateOrderSubmitState()
    local f = self.frame
    if not f or not f.submitBtn then
        return
    end

    if f.orderFormMode == "craft" then
        local acked = f.materialsAckCheck and f.materialsAckCheck:GetChecked()
        if acked then
            f.submitBtn:Enable()
        else
            f.submitBtn:Disable()
        end
    else
        f.submitBtn:Enable()
    end
end

function UI:PopulateCraftDropdown(dropdown, frameRef)
    local room = GuildieCraftsTest_GetActiveRoom()
    if not room then
        return
    end
    local professionId = GuildieCraftsTest_GetRoomProfession(room)
    GuildieCraftsTest_ClearDropdownItemTooltips()
    local buttonIndex = 0
    local indexToItemId = {}

    local clearInfo = UIDropDownMenu_CreateInfo()
    clearInfo.text = CRAFT_PLACEHOLDER
    clearInfo.value = 0
    MarkDropdownSelection(clearInfo, not frameRef.selectedCraft)
    clearInfo.func = function()
        frameRef.selectedCraft = nil
        SetDropdownDisplayText(dropdown, CRAFT_PLACEHOLDER)
        if frameRef.craftWarning then
            frameRef.craftWarning:Hide()
        end
        self:RelayoutOrderForm()
    end
    UIDropDownMenu_AddButton(clearInfo)
    buttonIndex = buttonIndex + 1

    local category = frameRef.selectedCraftCategory
    if not category then
        local info = UIDropDownMenu_CreateInfo()
        info.text = "Choose a category first"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info)
        GuildieCraftsTest_ApplyDropdownItemTooltips(indexToItemId)
        return
    end

    for _, craft in ipairs(GuildieCraftsTest_GetCraftsByCategory(professionId, category)) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = GuildieCraftsTest_FormatCraftLabel(craft)
        info.value = craft.itemId
        MarkDropdownSelection(info, frameRef.selectedCraft and frameRef.selectedCraft.itemId == craft.itemId)
        info.func = function()
            frameRef.selectedCraft = craft
            SetDropdownDisplayText(dropdown, craft.name)
            if frameRef.craftWarning then
                if GuildieCraftsTest_WorkshopHasRecipeForCraft(craft.name) then
                    frameRef.craftWarning:Hide()
                else
                    frameRef.craftWarning.text:SetText(CRAFT_RECIPE_WARNING)
                    frameRef.craftWarning:Show()
                end
            end
            self:RelayoutOrderForm()
        end
        UIDropDownMenu_AddButton(info)
        buttonIndex = buttonIndex + 1
        indexToItemId[buttonIndex] = craft.itemId
    end

    GuildieCraftsTest_ApplyDropdownItemTooltips(indexToItemId)
end

function UI:RelayoutOrderForm()
    local f = self.frame
    if not f or not f.orderDialog or not f.orderDialog.inset then
        return
    end

    local inset = f.orderDialog.inset
    local y = 8

    local function placeRow(label, dropdown)
        if label then
            label:ClearAllPoints()
            label:SetJustifyH("LEFT")
            label:SetPoint("TOPLEFT", inset, "TOPLEFT", 16, -(y + ORDER_DIALOG_LABEL_V_OFFSET))
        end
        if dropdown then
            dropdown:ClearAllPoints()
            dropdown:SetPoint("TOPLEFT", inset, "TOPLEFT", ORDER_DIALOG_FIELD_X, -y)
        end
        y = y + ORDER_DIALOG_ROW_GAP
    end

    if f.orderFormMode == "craft" then
        placeRow(f.roleLabel, f.roleDropdown)
        placeRow(f.craftCategoryLabel, f.craftCategoryDropdown)
        placeRow(f.craftLabel, f.craftDropdown)
        if f.craftWarning and f.craftWarning:IsShown() then
            f.craftWarning:ClearAllPoints()
            f.craftWarning:SetPoint(
                "TOPLEFT",
                f.craftDropdown,
                "BOTTOMLEFT",
                ORDER_DIALOG_DROPDOWN_TEXT_INSET,
                -ORDER_DIALOG_WARNING_GAP
            )
            y = y + ORDER_DIALOG_WARNING_HEIGHT + ORDER_DIALOG_WARNING_GAP
        end
    else
        placeRow(f.gearTypeLabel, f.gearTypeDropdown)
        if f.selectedGearCategory == "PVP" then
            if f.gearClassLabel then
                f.gearClassLabel:Show()
            end
            if f.gearClassDropdown then
                f.gearClassDropdown:Show()
            end
            placeRow(f.gearClassLabel, f.gearClassDropdown)
        else
            if f.gearClassLabel then
                f.gearClassLabel:Hide()
            end
            if f.gearClassDropdown then
                f.gearClassDropdown:Hide()
            end
        end
        placeRow(f.itemLabel, f.gearDropdown)
        placeRow(f.roleLabel, f.roleDropdown)

        for i = 1, 3 do
            if f.gemLabels and f.gemLabels[i] then
                f.gemLabels[i]:ClearAllPoints()
                f.gemLabels[i]:SetJustifyH("LEFT")
                f.gemLabels[i]:SetPoint("TOPLEFT", inset, "TOPLEFT", 16, -(y + ORDER_DIALOG_LABEL_V_OFFSET))
            end
            if f.gemDropdowns and f.gemDropdowns[i] then
                f.gemDropdowns[i]:ClearAllPoints()
                f.gemDropdowns[i]:SetPoint("TOPLEFT", inset, "TOPLEFT", ORDER_DIALOG_FIELD_X, -y)
            end
            y = y + ORDER_DIALOG_ROW_GAP

            local warning = f.gemWarnings and f.gemWarnings[i]
            if warning and warning:IsShown() then
                warning:ClearAllPoints()
                warning:SetPoint(
                    "TOPLEFT",
                    f.gemDropdowns[i],
                    "BOTTOMLEFT",
                    ORDER_DIALOG_DROPDOWN_TEXT_INSET,
                    -ORDER_DIALOG_WARNING_GAP
                )
                y = y + ORDER_DIALOG_WARNING_HEIGHT + ORDER_DIALOG_WARNING_GAP
            end
        end
    end

    y = y + ORDER_DIALOG_NOTES_GAP
    f.notesLabel:ClearAllPoints()
    f.notesLabel:SetJustifyH("LEFT")
    f.notesLabel:SetPoint("TOPLEFT", inset, "TOPLEFT", 16, -(y + ORDER_DIALOG_LABEL_V_OFFSET))
    f.notesInput:ClearAllPoints()
    f.notesInput:SetPoint("TOPLEFT", inset, "TOPLEFT", ORDER_DIALOG_FIELD_X, -y)
    SafeSetSize(f.notesInput, ORDER_DIALOG_DROPDOWN_WIDTH, 20)
    y = y + 4 + 20

    if f.orderFormMode == "craft" and f.materialsAckCheck then
        y = y + ORDER_DIALOG_MATERIALS_ACK_GAP
        f.materialsAckCheck:ClearAllPoints()
        f.materialsAckCheck:SetPoint("TOPLEFT", inset, "TOPLEFT", 12, -y)
        y = y + ORDER_DIALOG_MATERIALS_ACK_HEIGHT
    end

    local contentBottom = y + 8
    local dialogHeight = contentBottom + ORDER_DIALOG_TITLE_HEIGHT + 12 + ORDER_DIALOG_FOOTER_HEIGHT + 8
    if f.orderDialog then
        f.orderDialog:SetHeight(math.max(ORDER_DIALOG_MIN_HEIGHT, dialogHeight))
    end
end

function UI:CreateOrderDialog()
    local f = self.frame

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints(f)
    overlay:SetFrameLevel(f:GetFrameLevel() + 50)
    overlay:Hide()
    overlay:EnableMouse(true)
    overlay:SetScript("OnMouseDown", function()
        self:CloseOrderDialog()
    end)
    local overlayBg = overlay:CreateTexture(nil, "BACKGROUND")
    overlayBg:SetAllPoints()
    overlayBg:SetColorTexture(0, 0, 0, 0.55)
    f.orderDialogOverlay = overlay

    local dialog = CreateFrame("Frame", "GuildieCraftsTestOrderDialog", f)
    dialog:SetSize(ORDER_DIALOG_WIDTH, ORDER_DIALOG_MIN_HEIGHT)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(f:GetFrameLevel() + 60)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:Hide()
    GuildieCraftsTest_RegisterEscapeFrame(dialog)

    local shellBg = dialog:CreateTexture(nil, "BACKGROUND")
    shellBg:SetAllPoints()
    shellBg:SetColorTexture(0.20, 0.17, 0.13, 1)

    local titleBar = CreateFrame("Frame", nil, dialog)
    titleBar:SetPoint("TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", 0, 0)
    titleBar:SetHeight(ORDER_DIALOG_TITLE_HEIGHT)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        dialog:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        dialog:StopMovingOrSizing()
    end)

    local titleBg = titleBar:CreateTexture(nil, "BACKGROUND")
    titleBg:SetAllPoints()
    titleBg:SetColorTexture(0.14, 0.12, 0.10, 1)
    titleBar:SetFrameLevel(dialog:GetFrameLevel() + 2)

    local portrait = CreateFrame("Button", nil, titleBar)
    SafeSetSize(portrait, ORDER_DIALOG_PORTRAIT_SIZE, ORDER_DIALOG_PORTRAIT_SIZE)
    portrait:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 0, 0)
    portrait:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    portrait:SetNormalTexture(ORDER_DIALOG_ICON)
    local portraitBorder = portrait:CreateTexture(nil, "OVERLAY")
    portraitBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
    portraitBorder:SetAllPoints()
    dialog.portrait = portrait

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBar, "CENTER", 6, 0)
    title:SetText("Order form")

    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    closeBtn:SetFrameLevel(titleBar:GetFrameLevel() + 5)
    closeBtn:SetScript("OnClick", function()
        UI:CloseOrderDialog()
    end)

    local panel = CreateInsetPanel(dialog)
    panel:SetPoint("TOPLEFT", 4, -ORDER_DIALOG_TITLE_HEIGHT)
    panel:SetPoint("BOTTOMRIGHT", -4, 4)
    ApplyAddonPanelBackground(panel)

    local footer = CreateFrame("Frame", nil, panel)
    footer:SetPoint("BOTTOMLEFT", 12, 10)
    footer:SetPoint("BOTTOMRIGHT", -12, 10)
    footer:SetHeight(28)

    local inset = CreateFrame("Frame", nil, panel)
    inset:SetPoint("TOPLEFT", 12, -12)
    inset:SetPoint("BOTTOMRIGHT", -12, ORDER_DIALOG_FOOTER_HEIGHT)

    EnableDropdownDismissLayer(panel)

    dialog.panel = panel
    dialog.footer = footer
    dialog.inset = inset
    dialog.titleBar = titleBar
    f.orderDialog = dialog
end

function UI:OpenOrderDialog()
    if not GuildieCraftsTest_HasJoinedWorkshop() then
        print("|cff00ccffGuildieCraftsTest|r Select a workshop before placing an order.")
        return
    end
    local room = GuildieCraftsTest_GetActiveRoom()
    if room and not GuildieCraftsTest_IsWorkshopFullySupported(room) then
        print("|cff00ccffGuildieCraftsTest|r " .. GuildieCraftsTest_GetUnsupportedWorkshopMessage(room))
        return
    end
    if self.frame and self.frame.orderDialog then
        self:ConfigureOrderFormMode(room)
        if self.frame.materialsAckCheck then
            self.frame.materialsAckCheck:SetChecked(false)
        end
        self:UpdateOrderSubmitState()
        SafeCloseDropdownMenus()
        if self.frame.orderDialogOverlay then
            self.frame.orderDialogOverlay:Show()
        end
        self.frame.orderDialog:Show()
        self:RefreshOrderFormWarnings()
    end
end

function UI:RefreshOrderFormWarnings()
    local f = self.frame
    if not f then
        return
    end
    if f.orderFormMode == "craft" then
        if f.selectedCraft and f.craftWarning then
            if GuildieCraftsTest_WorkshopHasRecipeForCraft(f.selectedCraft.name) then
                f.craftWarning:Hide()
            else
                f.craftWarning.text:SetText(CRAFT_RECIPE_WARNING)
                f.craftWarning:Show()
            end
        end
        self:RelayoutOrderForm()
        return
    end
    if not f.gemWarnings then
        return
    end
    for i = 1, 3 do
        self:UpdateGemRecipeWarning(i)
    end
    self:RefreshGemDropdownLabels()
    self:RelayoutOrderForm()
end

function UI:CloseOrderDialog()
    if GuildieCraftsTest_IsLoggingOut and GuildieCraftsTest_IsLoggingOut() then
        if self.frame and self.frame.orderDialog then
            self.frame.orderDialog:Hide()
        end
        if self.frame and self.frame.orderDialogOverlay then
            self.frame.orderDialogOverlay:Hide()
        end
        return
    end
    SafeCloseDropdownMenus()
    if self.frame and self.frame.orderDialogOverlay then
        self.frame.orderDialogOverlay:Hide()
    end
    if self.frame and self.frame.orderDialog then
        self.frame.orderDialog:Hide()
    end
end

function UI:CreateOrderForm()
    local f = self.frame
    local dialog = f.orderDialog
    local inset = dialog.inset
    local y = -8

    f.gearTypeLabel = CreateLabel(inset, "Type:", "GameFontHighlight")
    f.gearTypeLabel:SetPoint("TOPLEFT", 16, y)

    f.selectedGearCategory = nil
    f.selectedGearClass = nil
    f.selectedGear = nil

    f.gearTypeDropdown = self:CreateGearTypeDropdown(
        "GuildieCraftsTestGearTypeDropdown",
        inset,
        "TOPLEFT",
        90,
        y + 8,
        f,
        ORDER_DIALOG_DROPDOWN_WIDTH
    )

    y = y - ORDER_DIALOG_ROW_GAP
    f.gearClassLabel = CreateLabel(inset, "Class:", "GameFontHighlight")
    f.gearClassLabel:SetPoint("TOPLEFT", 16, y)
    f.gearClassLabel:Hide()

    f.gearClassDropdown = self:CreateGearClassDropdown(
        "GuildieCraftsTestGearClassDropdown",
        inset,
        "TOPLEFT",
        90,
        y + 8,
        f,
        ORDER_DIALOG_DROPDOWN_WIDTH
    )

    y = y - ORDER_DIALOG_ROW_GAP
    f.itemLabel = CreateLabel(inset, "Gear:", "GameFontHighlight")
    f.itemLabel:SetPoint("TOPLEFT", 16, y)

    f.gearDropdown = self:CreateGearDropdown(
        "GuildieCraftsTestGearDropdown",
        inset,
        "TOPLEFT",
        90,
        y + 8,
        f,
        ORDER_DIALOG_DROPDOWN_WIDTH
    )

    f.selectedCraftCategory = nil
    f.selectedCraft = nil
    f.orderFormMode = "jc"

    f.craftCategoryLabel = CreateLabel(inset, "Category:", "GameFontHighlight")
    f.craftCategoryLabel:Hide()
    f.craftCategoryDropdown = CreateFrame("Frame", "GuildieCraftsTestCraftCategoryDropdown", inset, "UIDropDownMenuTemplate")
    f.craftCategoryDropdown:Hide()
    f.craftCategoryDropdown:SetPoint("TOPLEFT", 90, y + 8)
    UIDropDownMenu_Initialize(f.craftCategoryDropdown, function()
        local room = GuildieCraftsTest_GetActiveRoom()
        if not room then
            return
        end
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local clearInfo = UIDropDownMenu_CreateInfo()
        clearInfo.text = CRAFT_CATEGORY_PLACEHOLDER
        clearInfo.value = 0
        MarkDropdownSelection(clearInfo, not f.selectedCraftCategory)
        clearInfo.func = function()
            f.selectedCraftCategory = nil
            f.selectedCraft = nil
            SetDropdownDisplayText(f.craftCategoryDropdown, CRAFT_CATEGORY_PLACEHOLDER)
            SetDropdownDisplayText(f.craftDropdown, CRAFT_PLACEHOLDER)
            if f.craftWarning then
                f.craftWarning:Hide()
            end
            self:RelayoutOrderForm()
        end
        UIDropDownMenu_AddButton(clearInfo)

        for _, category in ipairs(GuildieCraftsTest_GetCraftCategories(GuildieCraftsTest_GetRoomProfession(room))) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = category
            MarkDropdownSelection(info, f.selectedCraftCategory == category)
            info.func = function()
                f.selectedCraftCategory = category
                f.selectedCraft = nil
                SetDropdownDisplayText(f.craftCategoryDropdown, category)
                SetDropdownDisplayText(f.craftDropdown, CRAFT_PLACEHOLDER)
                if f.craftWarning then
                    f.craftWarning:Hide()
                end
                self:RelayoutOrderForm()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    SetDropdownDisplayText(f.craftCategoryDropdown, CRAFT_CATEGORY_PLACEHOLDER)
    ConfigureOrderDropdown(f.craftCategoryDropdown, ORDER_DIALOG_DROPDOWN_WIDTH)

    f.craftLabel = CreateLabel(inset, "Gear:", "GameFontHighlight")
    f.craftLabel:Hide()
    f.craftDropdown = CreateFrame("Frame", "GuildieCraftsTestCraftDropdown", inset, "UIDropDownMenuTemplate")
    f.craftDropdown:Hide()
    f.craftDropdown:SetPoint("TOPLEFT", 90, y + 8)
    UIDropDownMenu_Initialize(f.craftDropdown, function()
        self:PopulateCraftDropdown(f.craftDropdown, f)
    end)
    SetDropdownDisplayText(f.craftDropdown, CRAFT_PLACEHOLDER)
    ConfigureOrderDropdown(f.craftDropdown, ORDER_DIALOG_DROPDOWN_WIDTH)
    GuildieCraftsTest_AttachDropdownTooltips(f.craftDropdown, function()
        return f.selectedCraft and f.selectedCraft.itemId
    end)

    local craftWarningFrame = CreateFrame("Frame", nil, inset)
    craftWarningFrame:SetSize(ORDER_DIALOG_DROPDOWN_WIDTH + 40, ORDER_DIALOG_WARNING_HEIGHT)
    craftWarningFrame:Hide()
    local craftWarning = craftWarningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    craftWarning:SetPoint("TOPLEFT", craftWarningFrame, "TOPLEFT", 0, 0)
    craftWarning:SetWidth(ORDER_DIALOG_DROPDOWN_WIDTH)
    craftWarning:SetJustifyH("LEFT")
    craftWarning:SetJustifyV("TOP")
    craftWarning:SetWordWrap(true)
    craftWarningFrame.text = craftWarning
    f.craftWarning = craftWarningFrame

    y = y - ORDER_DIALOG_ROW_GAP
    f.roleLabel = CreateLabel(inset, "Role:", "GameFontHighlight")
    f.roleLabel:SetPoint("TOPLEFT", 16, y)

    f.selectedRole = nil
    f.roleDropdown = CreateFrame("Frame", "GuildieCraftsTestRoleDropdown", inset, "UIDropDownMenuTemplate")
    f.roleDropdown:SetPoint("TOPLEFT", 90, y + 8)
    UIDropDownMenu_Initialize(f.roleDropdown, function()
        GuildieCraftsTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        info.text = ROLE_PLACEHOLDER
        info.notCheckable = true
        info.disabled = true
        UIDropDownMenu_AddButton(info)

        for _, role in ipairs(GuildieCraftsTest_ROLES) do
            info = UIDropDownMenu_CreateInfo()
            info.text = role
            MarkDropdownSelection(info, f.selectedRole == role)
            info.func = function()
                f.selectedRole = role
                SetDropdownDisplayText(f.roleDropdown, role)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    SetDropdownDisplayText(f.roleDropdown, ROLE_PLACEHOLDER)
    ConfigureOrderDropdown(f.roleDropdown, ORDER_DIALOG_DROPDOWN_WIDTH)

    y = y - ORDER_DIALOG_ROW_GAP
    f.gemLabels = {}
    f.gemDropdowns = {}
    f.gemWarnings = {}
    f.selectedGems = { "None", "None", "None" }

    for i = 1, 3 do
        local label = CreateLabel(inset, "Socket " .. i .. ":", "GameFontHighlight")
        label:SetPoint("TOPLEFT", 16, y)
        f.gemLabels[i] = label

        local index = i
        f.gemDropdowns[i] = self:CreateGemDropdown(
            "GuildieCraftsTestGemDropdown" .. i,
            inset,
            "TOPLEFT",
            90,
            y + 8,
            function(value)
                f.selectedGems[index] = value
                self:UpdateGemRecipeWarning(index)
                self:RelayoutOrderForm()
            end,
            function()
                return f.selectedGems[index]
            end,
            ORDER_DIALOG_DROPDOWN_WIDTH
        )

        local warningFrame = CreateFrame("Frame", nil, inset)
        warningFrame:SetSize(ORDER_DIALOG_DROPDOWN_WIDTH + 40, ORDER_DIALOG_WARNING_HEIGHT)
        warningFrame:Hide()

        local warning = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        warning:SetPoint("TOPLEFT", warningFrame, "TOPLEFT", 0, 0)
        warning:SetWidth(ORDER_DIALOG_DROPDOWN_WIDTH)
        warning:SetJustifyH("LEFT")
        warning:SetJustifyV("TOP")
        warning:SetWordWrap(true)
        warningFrame.text = warning
        f.gemWarnings[i] = warningFrame
    end

    f.notesLabel = CreateLabel(inset, "Notes:", "GameFontHighlight")
    f.notesInput = CreateFrame("EditBox", nil, inset, "InputBoxTemplate")
    SafeSetSize(f.notesInput, ORDER_DIALOG_DROPDOWN_WIDTH, 20)
    f.notesInput:SetAutoFocus(false)
    f.notesInput:SetMaxLetters(120)
    f.notesInput:SetScript("OnEditFocusGained", function(self)
        SetNotesPlaceholderState(self, true)
    end)
    f.notesInput:SetScript("OnEditFocusLost", function(self)
        SetNotesPlaceholderState(self, false)
    end)
    f.notesInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    ResetNotesInput(f.notesInput)

    f.materialsAckCheck = CreateFrame("CheckButton", "GuildieCraftsTestMaterialsAckCheck", inset, "UICheckButtonTemplate")
    f.materialsAckCheck:Hide()
    f.materialsAckCheck:SetSize(26, 26)
    f.materialsAckCheck.text = f.materialsAckCheck:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.materialsAckCheck.text:SetPoint("LEFT", f.materialsAckCheck, "RIGHT", 4, 0)
    f.materialsAckCheck.text:SetWidth(ORDER_DIALOG_DROPDOWN_WIDTH + 54)
    f.materialsAckCheck.text:SetJustifyH("LEFT")
    f.materialsAckCheck.text:SetWordWrap(true)
    f.materialsAckCheck.text:SetText(CRAFT_MATERIALS_ACK_TEXT)
    f.materialsAckCheck:SetScript("OnClick", function()
        self:UpdateOrderSubmitState()
    end)

    f.submitBtn = CreateFrame("Button", nil, dialog.footer, "UIPanelButtonTemplate")
    f.submitBtn:SetSize(110, 22)
    f.submitBtn:SetPoint("RIGHT", dialog.footer, "RIGHT", 0, 0)
    f.submitBtn:SetText("Submit Order")
    f.submitBtn:SetScript("OnClick", function()
        local _, err
        if f.orderFormMode == "craft" then
            if not f.materialsAckCheck or not f.materialsAckCheck:GetChecked() then
                print("|cff00ccffGuildieCraftsTest|r Confirm that you have the rest of the materials for this craft.")
                return
            end
            _, err = GuildieCraftsTest_CreateCraftOrder(
                f.selectedCraft,
                GetNotesInputText(f.notesInput),
                f.selectedRole
            )
        else
            _, err = GuildieCraftsTest_CreateOrder(
                f.selectedGear,
                f.selectedGems,
                GetNotesInputText(f.notesInput),
                f.selectedRole
            )
        end
        if err then
            print("|cff00ccffGuildieCraftsTest|r " .. err)
        else
            print("|cff00ccffGuildieCraftsTest|r Order submitted!")
            f.selectedGearCategory = nil
            f.selectedGearClass = nil
            f.selectedGear = nil
            f.selectedCraftCategory = nil
            f.selectedCraft = nil
            SetDropdownDisplayText(f.gearTypeDropdown, GEAR_TYPE_PLACEHOLDER)
            SetDropdownDisplayText(f.gearClassDropdown, GEAR_CLASS_PLACEHOLDER)
            SetDropdownDisplayText(f.gearDropdown, "Select gear...")
            SetDropdownDisplayText(f.craftCategoryDropdown, CRAFT_CATEGORY_PLACEHOLDER)
            SetDropdownDisplayText(f.craftDropdown, CRAFT_PLACEHOLDER)
            if f.craftWarning then
                f.craftWarning:Hide()
            end
            if f.gearClassLabel then
                f.gearClassLabel:Hide()
            end
            if f.gearClassDropdown then
                f.gearClassDropdown:Hide()
            end
            f.selectedRole = nil
            SetDropdownDisplayText(f.roleDropdown, ROLE_PLACEHOLDER)
            ResetNotesInput(f.notesInput)
            if f.materialsAckCheck then
                f.materialsAckCheck:SetChecked(false)
            end
            for i = 1, 3 do
                f.selectedGems[i] = "None"
                SetDropdownDisplayText(f.gemDropdowns[i], GEM_PLACEHOLDER)
                self:UpdateGemRecipeWarning(i)
            end
            self:RelayoutOrderForm()
            self:UpdateOrderSubmitState()
            self:CloseOrderDialog()
            self:Refresh()
        end
    end)

    f.cancelBtn = CreateFrame("Button", nil, dialog.footer, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(80, 22)
    f.cancelBtn:SetPoint("RIGHT", f.submitBtn, "LEFT", -8, 0)
    f.cancelBtn:SetText("Cancel")
    f.cancelBtn:SetScript("OnClick", function()
        self:CloseOrderDialog()
    end)

    self:RelayoutOrderForm()
end

function UI:UpdateGemRecipeWarning(index)
    local f = self.frame
    local warningFrame = f.gemWarnings and f.gemWarnings[index]
    if not warningFrame then
        return
    end

    local gemName = f.selectedGems[index]
    if gemName == "None" or GuildieCraftsTest_WorkshopHasRecipeForGem(gemName) then
        warningFrame:Hide()
        return
    end

    if warningFrame.text then
        warningFrame.text:SetText(GEM_RECIPE_WARNING)
    end
    warningFrame:Show()
end

function UI:CreateQueueList()
    local f = self.frame
    local inset = f.queueInset

    f.queueHeader = CreateLabel(inset, "Order Queue", "GameFontNormalLarge")
    f.queueHeader:SetPoint("TOPLEFT", 16, -12)

    f.placeOrderBtn = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
    f.placeOrderBtn:SetSize(120, 22)
    f.placeOrderBtn:SetText("Place Order")
    f.placeOrderBtn:Hide()
    f.placeOrderBtn:SetScript("OnClick", function()
        self:OpenOrderDialog()
    end)

    local scroll = CreateFrame("ScrollFrame", "GuildieCraftsTestScroll", inset, "UIPanelScrollFrameTemplate")

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(GetQueueContentWidth(), 400)
    scroll:SetScrollChild(content)

    f.scroll = scroll
    f.content = content
    f.rows = {}

    self:LayoutQueuePanel()
    LayoutQueueScrollbarOnce(inset)
end

function UI:ClearRows()
    if not self.frame then
        return
    end
    if not self.frame.rows then
        self.frame.rows = {}
        return
    end
    for _, row in ipairs(self.frame.rows) do
        row:Hide()
        row:SetParent(nil)
    end
    self.frame.rows = {}
end

function UI:CreateGemIconRow(parent, order, yOffset, startX)
    local x = startX or 48
    local y = yOffset
    local gemsPerRow = 2
    local gemLineSpacing = 32

    for i, gemName in ipairs(order.gems or {}) do
        if i > 1 and (i - 1) % gemsPerRow == 0 then
            x = startX or 48
            y = y - gemLineSpacing
        end

        local itemId = GuildieCraftsTest_GetGemItemId(gemName)
        if itemId then
            local btn = CreateFrame("Button", nil, parent)
            btn:SetSize(28, 28)
            btn:SetPoint("TOPLEFT", x, y)
            btn:SetNormalTexture(GetItemIcon(itemId) or "Interface\\Icons\\Inv_misc_gem_01")

            local border = btn:CreateTexture(nil, "OVERLAY")
            border:SetTexture("Interface\\Common\\WhiteIconFrame")
            border:SetAllPoints()

            GuildieCraftsTest_AttachItemTooltip(btn, function()
                return itemId
            end)

            local labelBtn = CreateFrame("Button", nil, parent)
            labelBtn:SetPoint("TOPLEFT", btn, "TOPRIGHT", 4, 0)
            labelBtn:SetSize(1, 14)
            local label = labelBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            label:SetPoint("LEFT", 0, 0)
            label:SetText(ColorizeGem(gemName))
            label:SetJustifyH("LEFT")
            labelBtn:SetWidth(label:GetStringWidth())
            GuildieCraftsTest_AttachItemTooltip(labelBtn, function()
                return itemId
            end)

            x = x + 32 + label:GetStringWidth() + 24
        end
    end
end

function UI:IsCraftOrder(order)
    if not order then
        return false
    end
    if order.orderKind == "craft" then
        return true
    end
    if order.gems and #order.gems > 0 then
        return false
    end
    return GuildieCraftsTest_GetCraftByItemId(order.itemId) ~= nil
        or GuildieCraftsTest_GetCraftByName(order.item) ~= nil
end

function UI:GetOrderRowHeight(order)
    local bandExtra = GetOrderRowBandExtra(order)

    if self:IsCraftOrder(order) then
        local height = 104 + bandExtra
        if order.notes and order.notes ~= "" then
            height = height + 22
        end
        return height
    end

    local height = ORDER_ROW_HEIGHT + 8 + bandExtra
    if order.gems and #order.gems > 2 then
        height = height + 30
    end
    if order.notes and order.notes ~= "" then
        height = height + 22
    end
    return height
end

function UI:CreateOrderRow(order, yOffset)
    local parent = self.frame.content
    local contentWidth = GetQueueContentWidth()
    local rowHeight = self:GetOrderRowHeight(order)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(contentWidth, rowHeight)
    row:SetPoint("TOPLEFT", 0, -yOffset)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", -2, 2)
    if order.status == "completed" then
        bg:SetColorTexture(0.15, 0.25, 0.12, 0.45)
    elseif order.status == "in_progress" then
        bg:SetColorTexture(0.12, 0.18, 0.28, 0.45)
    else
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.35)
    end

    local border = row:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetPoint("BOTTOMRIGHT", 0, 0)
    border:SetColorTexture(0.55, 0.45, 0.28, 0.35)

    local highlight = row:CreateTexture(nil, "ARTWORK")
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetPoint("TOPLEFT", 4, -4)
    highlight:SetPoint("BOTTOMRIGHT", -4, 4)
    highlight:SetAlpha(order.status == "pending" and 0.12 or 0.04)

    local bandExtra = GetOrderRowBandExtra(order)
    if order.status == "in_progress" then
        CreateInProgressBand(row, order, contentWidth)
    end

    local headerY = 8 + bandExtra
    local title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -headerY)
    if order.status == "in_progress" then
        title:SetText(string.format(
            "%s  %s",
            GuildieCraftsTest_ColorizePlayer(order.player, order.class),
            GuildieCraftsTest_GetRoleLabel(order.role)
        ))
    else
        title:SetText(string.format(
            "%s  %s  [%s]",
            GuildieCraftsTest_ColorizePlayer(order.player, order.class),
            GuildieCraftsTest_GetRoleLabel(order.role),
            GuildieCraftsTest_GetOrderStatusLabel(order)
        ))
    end
    title:SetWidth(contentWidth - 170)
    title:SetJustifyH("LEFT")

    local canManage = GuildieCraftsTest_CanManageOrder(order)
    local actionBtn

    if canManage and order.status ~= "completed" and order.status ~= "cancelled" then
        local btnArea = CreateFrame("Frame", nil, row)
        btnArea:SetSize(154, 20)
        btnArea:SetPoint("TOPRIGHT", -8, -headerY)

        if order.status == "pending" then
            actionBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            actionBtn:SetSize(84, 20)
            actionBtn:SetPoint("RIGHT", 0, 0)
            actionBtn:SetText("Pick order")
            actionBtn:SetScript("OnClick", function()
                GuildieCraftsTest_UpdateStatus(order.id, "in_progress")
                self:Refresh()
            end)
        elseif order.status == "in_progress" then
            actionBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            actionBtn:SetSize(70, 20)
            actionBtn:SetPoint("RIGHT", 0, 0)
            actionBtn:SetText("Done")
            actionBtn:SetScript("OnClick", function()
                GuildieCraftsTest_UpdateStatus(order.id, "completed")
                self:Refresh()
            end)
        end

        if actionBtn and order.status ~= "completed" then
            local downBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            downBtn:SetSize(24, 20)
            downBtn:SetPoint("RIGHT", actionBtn, "LEFT", -6, 0)
            downBtn:SetText("v")
            downBtn:SetScript("OnClick", function()
                local ok, err = GuildieCraftsTest_MoveOrder(order.id, 1)
                if not ok and err then
                    print("|cff00ccffGuildieCraftsTest|r " .. err)
                end
                self:Refresh()
            end)

            local upBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            upBtn:SetSize(24, 20)
            upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
            upBtn:SetText("^")
            upBtn:SetScript("OnClick", function()
                local ok, err = GuildieCraftsTest_MoveOrder(order.id, -1)
                if not ok and err then
                    print("|cff00ccffGuildieCraftsTest|r " .. err)
                end
                self:Refresh()
            end)
        end
    end

    local gearItemId = order.itemId or GuildieCraftsTest_GetGearItemId(order.item)
    local isCraftOrder = self:IsCraftOrder(order)
    local contentTop = -(28 + bandExtra)
    local valueX = ORDER_ROW_VALUE_X

    local itemLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    itemLabel:SetPoint("TOPLEFT", 10, contentTop - 2)
    itemLabel:SetText("Gear:")

    if gearItemId then
        local gearIcon = CreateFrame("Button", nil, row)
        gearIcon:SetSize(28, 28)
        gearIcon:SetPoint("TOPLEFT", valueX, contentTop)
        gearIcon:SetNormalTexture(GetItemIcon(gearItemId) or "Interface\\Icons\\INV_Misc_QuestionMark")

        local borderTex = gearIcon:CreateTexture(nil, "OVERLAY")
        borderTex:SetTexture("Interface\\Common\\WhiteIconFrame")
        borderTex:SetAllPoints()

        GuildieCraftsTest_AttachItemTooltip(gearIcon, function()
            if order.itemLink then
                return order.itemLink
            end
            return gearItemId
        end)
    end

    local itemBtn = CreateFrame("Button", nil, row)
    itemBtn:SetPoint("TOPLEFT", gearItemId and (valueX + 32) or valueX, contentTop - 4)
    itemBtn:SetSize(contentWidth - (gearItemId and 120 or 88), 16)
    local itemText = itemBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    itemText:SetPoint("LEFT", 0, 0)
    itemText:SetJustifyH("LEFT")
    itemText:SetText(ColorizeItem(order.item or "Unknown item"))
    itemBtn:SetWidth(itemText:GetStringWidth() + 4)
    if gearItemId or order.itemLink then
        GuildieCraftsTest_AttachItemTooltip(itemBtn, function()
            if order.itemLink then
                return order.itemLink
            end
            return gearItemId
        end)
    end

    local gemsTop = contentTop - 34
    local detailY = gemsTop

    if not isCraftOrder then
        local gemsLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        gemsLabel:SetPoint("TOPLEFT", 10, gemsTop - 2)
        gemsLabel:SetText("Gems:")
        self:CreateGemIconRow(row, order, gemsTop, valueX)
        detailY = gemsTop - 34
    else
        local materialLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        materialLabel:SetPoint("TOPLEFT", 10, detailY - 2)
        materialLabel:SetText("|cffccccccMaterial:|r")

        local materialName = order.material or "Heart of Darkness"
        local count = order.materialCount
        if not count then
            local craft = GuildieCraftsTest_GetCraftByItemId(order.itemId)
                or GuildieCraftsTest_GetCraftByName(order.item)
            count = craft and craft.hodCost or 1
        end
        local materialItemId = order.materialItemId
            or GuildieCraftsTest_GetScarceMaterialItemId(materialName)

        local materialX = valueX

        local countLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        countLabel:SetPoint("TOPLEFT", materialX, detailY - 4)
        countLabel:SetJustifyH("LEFT")
        countLabel:SetText(string.format("|cffffffff%dx|r", count))
        materialX = materialX + countLabel:GetStringWidth() + 4

        if materialItemId then
            local materialIcon = CreateFrame("Button", nil, row)
            materialIcon:SetSize(28, 28)
            materialIcon:SetPoint("TOPLEFT", materialX, detailY)
            materialIcon:SetNormalTexture(GetItemIcon(materialItemId) or "Interface\\Icons\\INV_Misc_QuestionMark")

            local materialBorder = materialIcon:CreateTexture(nil, "OVERLAY")
            materialBorder:SetTexture("Interface\\Common\\WhiteIconFrame")
            materialBorder:SetAllPoints()

            GuildieCraftsTest_AttachItemTooltip(materialIcon, function()
                return materialItemId
            end)
            materialX = materialX + 32
        end

        local materialBtn = CreateFrame("Button", nil, row)
        materialBtn:SetPoint("TOPLEFT", materialX, detailY - 4)
        local materialText = materialBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        materialText:SetPoint("LEFT", 0, 0)
        materialText:SetJustifyH("LEFT")
        materialText:SetText(ColorizeItem(materialName))
        materialBtn:SetSize(materialText:GetStringWidth() + 4, 16)
        if materialItemId then
            GuildieCraftsTest_AttachItemTooltip(materialBtn, function()
                return materialItemId
            end)
        end
        detailY = detailY - 34
    end

    if order.notes and order.notes ~= "" then
        local notesLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notesLabel:SetPoint("TOPLEFT", 10, detailY - 2)
        notesLabel:SetText("|cffccccccNote:|r")
        local notes = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        notes:SetPoint("TOPLEFT", valueX, detailY - 3)
        notes:SetWidth(contentWidth - valueX - 12)
        notes:SetJustifyH("LEFT")
        notes:SetWordWrap(true)
        notes:SetText("|cffffffff" .. order.notes .. "|r")
    end

    local player = UnitName("player")
    local isOwner = order.player == player
    local room = order.roomId and GuildieCraftsTest_GetRoom(order.roomId)
    local canManageWorkshop = room and GuildieCraftsTest_CanManageWorkshop(room, player)

    if canManageWorkshop then
        local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        deleteBtn:SetSize(60, 20)
        deleteBtn:SetPoint("TOPRIGHT", -8, -32)
        deleteBtn:SetText("Delete")
        deleteBtn:SetScript("OnClick", function()
            local ok, err = GuildieCraftsTest_DeleteOrder(order.id)
            if not ok and err then
                print("|cff00ccffGuildieCraftsTest|r " .. err)
            end
            self:Refresh()
        end)
    elseif (isOwner or canManage) and order.status == "pending" then
        local cancelBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        cancelBtn:SetSize(60, 20)
        cancelBtn:SetPoint("TOPRIGHT", -8, -32)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function()
            GuildieCraftsTest_CancelOrder(order.id)
            self:Refresh()
        end)
    end

    table.insert(self.frame.rows, row)
end

function UI:CreateQueueSeparator(yOffset, label)
    local parent = self.frame.content
    local contentWidth = GetQueueContentWidth()
    local sep = CreateFrame("Frame", nil, parent)
    sep:SetSize(contentWidth, 28)
    sep:SetPoint("TOPLEFT", 0, -yOffset)

    local line = sep:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("LEFT", 8, 0)
    line:SetPoint("RIGHT", -8, 0)
    line:SetColorTexture(0.55, 0.45, 0.28, 0.45)

    local text = sep:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    text:SetPoint("LEFT", 8, -10)
    text:SetText(label)

    table.insert(self.frame.rows, sep)
    return 28 + 8
end

function UI:UpdatePortraitIcon(room)
    if not self.frame then
        return
    end

    local icon = GuildieCraftsTest_GetWorkshopPortraitIcon(room)
    if tostring(self.frame.portraitIcon) == tostring(icon) then
        return
    end

    self.frame.portraitIcon = icon
    SetFramePortraitIcon(self.frame, icon)
end

function UI:Refresh()
    if not self.frame or (GuildieCraftsTest_IsLoggingOut and GuildieCraftsTest_IsLoggingOut()) then
        return
    end

    GuildieCraftsTest_ValidateActiveRoom()
    self:UpdateTabAccess()

    local room = GuildieCraftsTest_GetActiveRoom()
    self:UpdatePortraitIcon(room)
    if room and GuildieCraftsTest_IsPromotedJewelcrafter(room, UnitName("player")) then
        local crafterSingular = GuildieCraftsTest_GetRoomCrafterSingular(room)
        self.frame.jcLabel:SetText("|cff00ff00Workshop " .. crafterSingular .. "|r")
    else
        self.frame.jcLabel:SetText("")
    end

    if GuildieCraftsTest_HasJoinedWorkshop() and room then
        self.frame.roomLabel:SetText(string.format(
            "Workshop: |cff00ff00%s|r  |cff888888(%s)|r",
            room.name,
            GuildieCraftsTest_FormatWorkshopScope(room)
        ))
    else
        self.frame.roomLabel:SetText("|cffffcc00Select a workshop on the Workshop tab to unlock Orders, Stock and Recipes.|r")
    end

    if self.activeTab == "workshop" then
        self:RefreshWorkshopPanel()
    elseif self.activeTab == "stock" and GuildieCraftsTest_HasJoinedWorkshop() then
        self:RefreshStockPanel()
    elseif self.activeTab == "recipes" and GuildieCraftsTest_HasJoinedWorkshop() then
        self:RefreshRecipesPanel()
    end

    if self.activeTab == "orders" or self.activeTab == "completed" then
        self:LayoutQueuePanel()
    end

    self:ClearRows()
    if not self.frame.content then
        return
    end
    if self.activeTab == "orders" and GuildieCraftsTest_HasJoinedWorkshop() then
        local orders = GuildieCraftsTest_GetActiveOrders()
        local y = 0
        local lastGroup = nil
        for _, order in ipairs(orders) do
            local group = order.status == "in_progress" and "in_progress" or "pending"
            if lastGroup == "pending" and group == "in_progress" then
                y = y + self:CreateQueueSeparator(y, "Being worked on")
            end
            self:CreateOrderRow(order, y)
            y = y + self:GetOrderRowHeight(order) + ORDER_ROW_GAP
            lastGroup = group
        end
        self.frame.content:SetWidth(GetQueueContentWidth())
        self.frame.content:SetHeight(math.max(200, y))
    elseif self.activeTab == "completed" and GuildieCraftsTest_HasJoinedWorkshop() then
        local orders = GuildieCraftsTest_GetCompletedOrders()
        local y = 0
        for _, order in ipairs(orders) do
            self:CreateOrderRow(order, y)
            y = y + self:GetOrderRowHeight(order) + ORDER_ROW_GAP
        end
        self.frame.content:SetWidth(GetQueueContentWidth())
        self.frame.content:SetHeight(math.max(200, y))
    else
        self.frame.content:SetHeight(200)
    end
end

function UI:Toggle()
    if self.frame:IsShown() then
        SafeCloseDropdownMenus()
        self.frame:Hide()
    else
        self:SafeRefresh()
        self.frame:Show()
    end
end

function UI:Show()
    self:SafeRefresh()
    self.frame:Show()
end

function UI:SafeRefresh()
    local ok, err = pcall(function()
        self:Refresh()
    end)
    if not ok then
        print("|cffff0000GuildieCraftsTest refresh error:|r " .. tostring(err))
    end
end

function UI:Hide()
    SafeCloseDropdownMenus()
    self.frame:Hide()
end
