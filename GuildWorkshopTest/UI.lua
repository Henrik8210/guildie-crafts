local ADDON_NAME = ...

GuildWorkshopTest = GuildWorkshop or {}
local UI = {}
GuildWorkshopTest.UI = UI

local FRAME_WIDTH = 540
local FRAME_HEIGHT = 660
local ORDER_ROW_HEIGHT = 100
local ORDER_ROW_GAP = 10
local RECIPE_ROW_HEIGHT = 22
local RECIPE_SECTION_GAP = 18
local RECIPE_HEADER_AFTER_GAP = 8
local ORDER_DIALOG_WIDTH = 430
local ORDER_DIALOG_MIN_HEIGHT = 400
local ORDER_DIALOG_TITLE_HEIGHT = 50
local ORDER_DIALOG_MAIL_ICON = "Interface\\MailFrame\\Mail-Icon"
local ORDER_DIALOG_ROW_GAP = 32
local ORDER_DIALOG_WARNING_HEIGHT = 36
local ORDER_DIALOG_WARNING_GAP = 2
local ORDER_DIALOG_NOTES_GAP = 16
local GEM_RECIPE_WARNING = "|cffffff00Warning: Your guild has not yet obtained\nthe recipe for this gem cut.|r"
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
local NOTES_PLACEHOLDER = "Fx. this is my BiS gear..."
local GEM_PLACEHOLDER = "Select gem..."
local GEAR_TYPE_PLACEHOLDER = "Select type..."
local GEAR_CLASS_PLACEHOLDER = "Select class..."
local ROLE_PLACEHOLDER = "Select role..."
local CRAFT_CATEGORY_PLACEHOLDER = "Select category..."
local CRAFT_PLACEHOLDER = "Select craft..."

local function RegisterCloseWorkshopPopup()
    if GuildWorkshopTest.closeWorkshopPopupRegistered then
        return
    end
    GuildWorkshopTest.closeWorkshopPopupRegistered = true
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["GuildWorkshopTest_CONFIRM_CLOSE_WORKSHOP"] = {
        text = "Are you sure you wish to close the workshop %s?",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self)
            local data = self.data
            if not data or not data.roomId then
                return
            end
            local ok, err = GuildWorkshopTest_CloseWorkshop(data.roomId)
            if not ok then
                print("|cff00ccffGuildWorkshopTest|r " .. (err or "Could not close workshop."))
            else
                print("|cff00ccffGuildWorkshopTest|r Workshop closed.")
            end
            GuildWorkshopTest_RefreshUI()
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
    local dialog = StaticPopup_Show("GuildWorkshopTest_CONFIRM_CLOSE_WORKSHOP", room.name)
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
    local color = GEM_COLORS[GuildWorkshopTest_GetGemColor(name)] or GEM_COLORS.Unknown
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
    local scrollBar = _G["GuildWorkshopTestScrollScrollBar"]
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

local function CreateLabel(parent, text, template)
    local label = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    label:SetText(text)
    return label
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
    local ok, frame = pcall(CreateFrame, "Frame", "GuildWorkshopTestFrame", UIParent, "PortraitFrameTemplate")
    if ok and frame then
        return frame
    end
    frame = CreateFrame("Frame", "GuildWorkshopTestFrame", UIParent)
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
    if not GuildWorkshopTest.UI or not GuildWorkshopTest.UI.frame then
        return
    end
    local f = GuildWorkshopTest.UI.frame
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
    if GuildWorkshopTest_GetVersion then
        return GuildWorkshopTest_GetVersion()
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
    for _, gem in ipairs(GuildWorkshopTest_GetCutGems()) do
        if gem.color ~= currentColor then
            currentColor = gem.color
            table.insert(self.gemMenuEntries, { kind = "header", text = gem.color .. " gems" })
        end
        table.insert(self.gemMenuEntries, { kind = "gem", gem = gem })
    end
end

function UI:RefreshJoinDropdownCache()
    self.joinRoomOptions = GuildWorkshopTest_GetOpenRooms()
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

    GuildWorkshopTest_RegisterEscapeFrame(f)

    f:SetScript("OnHide", function()
        HideOpenDropdownLists()
        HideOrderDialogSilently()
    end)

    SetFrameTitle(f, "Guild Workshop")
    if f.PortraitContainer and f.PortraitContainer.portrait then
        f.PortraitContainer.portrait:SetTexture("Interface\\Icons\\Inv_Jewelcrafting_CrimsonSpinel_02")
    elseif f.SetPortraitTexture then
        f:SetPortraitTexture("Interface\\Icons\\Inv_Jewelcrafting_CrimsonSpinel_02")
    end

    f.subtitle = CreateLabel(f, "Guild crafting workshops — orders, stock, and recipes", "GameFontHighlightSmall")
    f.subtitle:SetPoint("TOP", 0, -28)

    f.roomLabel = CreateLabel(f, "", "GameFontHighlightSmall")
    f.roomLabel:SetPoint("TOPLEFT", 72, -50)
    f.roomLabel:SetWidth(FRAME_WIDTH - 160)
    f.roomLabel:SetJustifyH("LEFT")

    f.jcLabel = CreateLabel(f, "", "GameFontNormalSmall")
    f.jcLabel:SetPoint("TOPLEFT", f.roomLabel, "BOTTOMLEFT", 0, -6)
    f.jcLabel:SetWidth(FRAME_WIDTH - 160)
    f.jcLabel:SetJustifyH("LEFT")

    f.creditsDev = CreateLabel(f, "Developed by " .. GuildWorkshopTest_ColorizePlayer("Nobunda", "SHAMAN"), "GameFontDisableSmall")
    f.creditsDev:SetPoint("BOTTOM", 0, 22)
    f.creditsDev:SetJustifyH("CENTER")

    f.creditsTest = CreateLabel(f, "Tested by " .. GuildWorkshopTest_ColorizePlayer("Justtwo", "WARLOCK"), "GameFontDisableSmall")
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
        local room = GuildWorkshopTest_GetActiveRoom()
        if f.placeOrderBtn then
            if room and GuildWorkshopTest_IsWorkshopFullySupported(room) then
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
    local joined = GuildWorkshopTest_HasJoinedWorkshop()
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

    if not skipAccessCheck and (tabId == "orders" or tabId == "completed" or tabId == "stock" or tabId == "recipes") and not GuildWorkshopTest_HasJoinedWorkshop() then
        tabId = "workshop"
    end

    GuildWorkshopTest_ValidateActiveRoom()
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

    if (tabId == "orders" or tabId == "completed" or tabId == "recipes") and GuildWorkshopTest_HasJoinedWorkshop() and IsInGuild() then
        GuildWorkshopTest.Sync:RequestSync()
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

    panel.title = CreateLabel(panel, "Guild Workshops", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -12)

    panel.status = CreateLabel(panel, "", "GameFontHighlight")
    panel.status:SetPoint("TOPLEFT", 16, -36)
    panel.status:SetWidth(FRAME_WIDTH - 48)

    panel.guildNotice = CreateLabel(panel, "", "GameFontHighlight")
    panel.guildNotice:SetPoint("TOPLEFT", 16, -64)
    panel.guildNotice:SetWidth(FRAME_WIDTH - 48)
    panel.guildNotice:SetJustifyH("LEFT")

    f.selectedCreateExpansion = GuildWorkshopTest_GetDefaultExpansion()
    f.selectedCreatePhase = GuildWorkshopTest_GetDefaultPhase()
    f.selectedCreateProfession = "jewelcrafting"

    panel.createNameLabel = CreateLabel(panel, "Name:", "GameFontHighlight")
    panel.createNameLabel:SetPoint("TOPLEFT", 16, -92)

    panel.nameInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    panel.nameInput:SetSize(280, 20)
    panel.nameInput:SetPoint("TOPLEFT", 120, -88)
    panel.nameInput:SetAutoFocus(false)
    panel.nameInput:SetMaxLetters(40)

    panel.createPhaseLabel = CreateLabel(panel, "Expansion:", "GameFontHighlight")
    panel.createPhaseLabel:SetPoint("TOPLEFT", 16, -120)

    panel.expansionDropdown = CreateFrame("Frame", "GuildWorkshopTestExpansionDropdown", panel, "UIDropDownMenuTemplate")
    panel.expansionDropdown:SetPoint("TOPLEFT", 120, -116)
    UIDropDownMenu_SetWidth(panel.expansionDropdown, 280)
    UIDropDownMenu_Initialize(panel.expansionDropdown, function()
        GuildWorkshopTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        for _, option in ipairs(GuildWorkshopTest_GetExpansionPhaseOptions()) do
            info = UIDropDownMenu_CreateInfo()
            info.text = option.label
            MarkDropdownSelection(info,
                f.selectedCreateExpansion == option.expansion and f.selectedCreatePhase == option.phase)
            info.func = function()
                f.selectedCreateExpansion = option.expansion
                f.selectedCreatePhase = option.phase
                SetDropdownDisplayText(panel.expansionDropdown, option.label)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    SetDropdownDisplayText(panel.expansionDropdown, "TBC — Phase 3")

    panel.createProfessionLabel = CreateLabel(panel, "Profession:", "GameFontHighlight")
    panel.createProfessionLabel:SetPoint("TOPLEFT", 16, -148)

    panel.professionDropdown = CreateFrame("Frame", "GuildWorkshopTestProfessionDropdown", panel, "UIDropDownMenuTemplate")
    panel.professionDropdown:SetPoint("TOPLEFT", 120, -144)
    UIDropDownMenu_SetWidth(panel.professionDropdown, 280)
    UIDropDownMenu_Initialize(panel.professionDropdown, function()
        GuildWorkshopTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        for _, profession in ipairs(GuildWorkshopTest_GetProfessionOptions()) do
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
    panel.createBtn:SetPoint("TOPLEFT", 120, -176)
    panel.createBtn:SetText("Create")
    panel.createBtn:SetScript("OnClick", function()
        local _, err = GuildWorkshopTest_CreateWorkshop(
            panel.nameInput:GetText(),
            f.selectedCreateExpansion,
            f.selectedCreatePhase,
            f.selectedCreateProfession
        )
        if err then
            print("|cff00ccffGuildWorkshopTest|r " .. err)
        else
            panel.nameInput:SetText("")
            print("|cff00ccffGuildWorkshopTest|r Workshop created.")
            self:Refresh()
        end
    end)

    panel.joinLabel = CreateLabel(panel, "Select a workshop:", "GameFontHighlight")
    panel.joinLabel:SetPoint("TOPLEFT", 16, -208)

    panel.joinDropdown = CreateFrame("Frame", "GuildWorkshopTestJoinDropdown", panel, "UIDropDownMenuTemplate")
    panel.joinDropdown:SetPoint("TOPLEFT", 120, -204)
    UIDropDownMenu_SetWidth(panel.joinDropdown, 280)
    UIDropDownMenu_Initialize(panel.joinDropdown, function()
        GuildWorkshopTest_ClearDropdownItemTooltips()
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
                GuildWorkshopTest_FormatWorkshopScope(openRoom)
            )
            MarkDropdownSelection(info, GuildWorkshopTest_GetActiveRoomId() == openRoom.id)
            info.func = function()
                local _, err = GuildWorkshopTest_JoinWorkshop(openRoom.id)
                if err then
                    print("|cff00ccffGuildWorkshopTest|r " .. err)
                else
                    print("|cff00ccffGuildWorkshopTest|r Selected " .. openRoom.name .. ".")
                    SetDropdownDisplayText(panel.joinDropdown, openRoom.name)
                    UI:Refresh()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    panel.openLabel = CreateLabel(panel, "Workshop:", "GameFontHighlight")
    panel.openLabel:SetPoint("TOPLEFT", 16, -242)

    panel.roomList = CreateLabel(panel, "", "GameFontHighlightSmall")
    panel.roomList:SetPoint("TOPLEFT", 16, -260)
    panel.roomList:SetWidth(FRAME_WIDTH - 48)
    panel.roomList:SetJustifyH("LEFT")

    panel.closeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.closeBtn:SetSize(120, 22)
    panel.closeBtn:SetPoint("TOPRIGHT", -16, -10)
    panel.closeBtn:SetText("Close workshop")
    panel.closeBtn:SetScript("OnClick", function()
        local room = GuildWorkshopTest_GetActiveRoom()
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
        local _, err = GuildWorkshopTest_DeselectWorkshop()
        if err then
            print("|cff00ccffGuildWorkshopTest|r " .. err)
        else
            print("|cff00ccffGuildWorkshopTest|r Workshop deselected. You remain a member — select another below.")
            SetDropdownDisplayText(panel.joinDropdown, "Select a workshop...")
        end
        self:Refresh()
    end)

    panel.pickerControls = {
        panel.createNameLabel,
        panel.nameInput,
        panel.createPhaseLabel,
        panel.expansionDropdown,
        panel.createProfessionLabel,
        panel.professionDropdown,
        panel.createBtn,
        panel.joinLabel,
        panel.joinDropdown,
    }

    panel.help = CreateLabel(panel, "Create or select a workshop for a specific expansion, phase, and profession.", "GameFontDisableSmall")
    panel.help:SetPoint("BOTTOMLEFT", 16, 12)
    panel.help:SetWidth(FRAME_WIDTH - 48)
    panel.help:SetJustifyH("LEFT")

    panel.membersHelp = CreateLabel(panel, "Co-leaders can promote/demote crafters for all members except the leader. Only the leader manages co-leaders.", "GameFontDisableSmall")
    panel.membersHelp:SetWidth(FRAME_WIDTH - 48)
    panel.membersHelp:SetJustifyH("LEFT")
    panel.membersHelp:Hide()

    panel.membersLabel = CreateLabel(panel, "Members:", "GameFontHighlight")
    panel.membersLabel:SetPoint("TOPLEFT", 16, -240)

    local scroll = CreateFrame("ScrollFrame", "GuildWorkshopTestWorkshopMembersScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -258)
    scroll:SetPoint("BOTTOMRIGHT", -28, 36)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(FRAME_WIDTH - 88, 200)
    scroll:SetScrollChild(content)

    panel.memberScroll = scroll
    panel.memberContent = content
    panel.memberRows = {}

    f.workshopPanel = panel
end

function UI:LayoutWorkshopPanel(panel, showPicker)
    for _, control in ipairs(panel.pickerControls or {}) do
        control:SetShown(showPicker)
    end

    panel.openLabel:ClearAllPoints()
    panel.roomList:ClearAllPoints()
    if showPicker then
        panel.openLabel:SetPoint("TOPLEFT", 16, -242)
        panel.openLabel:Show()
        panel.roomList:SetPoint("TOPLEFT", 16, -260)
    else
        panel.openLabel:Hide()
        panel.roomList:SetPoint("TOPLEFT", panel.guildNotice, "BOTTOMLEFT", 0, -12)
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

    local room = GuildWorkshopTest_GetActiveRoom()
    panel.membersHelp:SetShown(room ~= nil)
    if room then
        local crafterPlural = GuildWorkshopTest_GetCrafterLabel(GuildWorkshopTest_GetRoomProfession(room))
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
    panel.membersHelp:SetPoint("TOPLEFT", panel.roomList, "BOTTOMLEFT", 0, -12)

    panel.membersLabel:ClearAllPoints()
    panel.membersLabel:SetPoint("TOPLEFT", panel.membersHelp, "BOTTOMLEFT", 0, -6)
    panel.memberScroll:ClearAllPoints()
    panel.memberScroll:SetPoint("TOPLEFT", panel.membersLabel, "BOTTOMLEFT", -4, -4)
    panel.memberScroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 36)

    local player = UnitName("player")
    local isManager = GuildWorkshopTest_CanManageWorkshop(room, player)
    local isOwner = GuildWorkshopTest_IsWorkshopOwner(room, player)
    local members = GuildWorkshopTest_GetSortedRoomMembers(room)
    local crafterSingular = GuildWorkshopTest_GetRoomCrafterSingular(room)
    local crafterShort = GuildWorkshopTest_GetRoomCrafterShortLabel(room)
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
        label:SetText(GuildWorkshopTest_ColorizePlayer(name) .. tagText)

        local isSelf = name == player
        local isLeaderRow = name == room.leader
        local isTargetCoLeader = room.coLeaders and room.coLeaders[name]
        local isJewelcrafter = room.collaborators and room.collaborators[name]
        local canManageJC = isManager and ((isLeaderRow and isSelf) or not isLeaderRow)
        local canManageCoLeader = isOwner and not isLeaderRow

        if canManageJC or canManageCoLeader then
            local right = -8
            local function placeBtn(text, width, onClick)
                local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                btn:SetSize(width, 22)
                btn:SetPoint("RIGHT", right, 0)
                btn:SetText(text)
                btn:SetScript("OnClick", onClick)
                right = right - width - 4
            end

            if canManageCoLeader and not isTargetCoLeader then
                placeBtn("Make co-leader", 124, function()
                    local ok, err = GuildWorkshopTest_AddCoLeader(room.id, name)
                    if not ok then
                        print("|cff00ccffGuildWorkshopTest|r " .. (err or "Action failed."))
                    else
                        self:Refresh()
                    end
                end)
            end

            if canManageJC then
                if isJewelcrafter then
                    placeBtn("Demote " .. crafterShort, 88, function()
                        local ok, err = GuildWorkshopTest_DemoteCollaborator(room.id, name)
                        if not ok then
                            print("|cff00ccffGuildWorkshopTest|r " .. (err or "Action failed."))
                        else
                            self:Refresh()
                        end
                    end)
                else
                    placeBtn("Make " .. crafterShort, 88, function()
                        local ok, err = GuildWorkshopTest_PromoteMember(room.id, name)
                        if not ok then
                            print("|cff00ccffGuildWorkshopTest|r " .. (err or "Action failed."))
                        else
                            self:Refresh()
                        end
                    end)
                end
            end

            if canManageCoLeader and isTargetCoLeader then
                placeBtn("Demote co-leader", 124, function()
                    local ok, err = GuildWorkshopTest_RemoveCoLeader(room.id, name)
                    if not ok then
                        print("|cff00ccffGuildWorkshopTest|r " .. (err or "Action failed."))
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
    if IsInGuild() then
        GuildWorkshopTest.Sync:RequestSync()
    end

    local inGuild = IsInGuild()
    if inGuild then
        panel.guildNotice:SetText("|cff888888Guild-only — workshops are never shared outside your guild.|r")
        panel.createBtn:Enable()
        panel.nameInput:Enable()
        UIDropDownMenu_EnableDropDown(panel.expansionDropdown)
        UIDropDownMenu_EnableDropDown(panel.professionDropdown)
    else
        panel.guildNotice:SetText("|cffff0000You must be in a guild to create or select workshops.|r")
        panel.createBtn:Disable()
        panel.nameInput:Disable()
        UIDropDownMenu_DisableDropDown(panel.expansionDropdown)
        UIDropDownMenu_DisableDropDown(panel.professionDropdown)
    end

    local room = GuildWorkshopTest_GetActiveRoom()
    local showPicker = room == nil
    self:LayoutWorkshopPanel(panel, showPicker)

    if room then
        local role = "Member"
        local player = UnitName("player")
        local crafterSingular = GuildWorkshopTest_GetRoomCrafterSingular(room)
        if room.leader == player then
            role = "Leader"
        elseif GuildWorkshopTest_IsRoomCoLeader(room, player) then
            role = "Co-leader"
        end
        if room.collaborators and room.collaborators[player] then
            if role == "Leader" then
                role = "Leader, " .. crafterSingular
            elseif role == "Co-leader" then
                role = "Co-leader, " .. crafterSingular
            else
                role = crafterSingular
            end
        end
        panel.status:SetText(string.format(
            "Active: |cff00ff00%s|r  |cff888888(%s)|r  (Leader: %s) — You: %s",
            room.name,
            GuildWorkshopTest_FormatWorkshopScope(room),
            GuildWorkshopTest_ColorizePlayer(room.leader),
            role
        ))
    else
        panel.status:SetText("|cff888888No workshop selected — select or create one to place orders.|r")
    end

    if room then
        panel.roomList:SetText(string.format(
            "%s — %s  |cff888888(%s)|r",
            room.name,
            GuildWorkshopTest_ColorizePlayer(room.leader),
            GuildWorkshopTest_FormatWorkshopScope(room)
        ))
    elseif #GuildWorkshopTest_GetOpenRooms() == 0 then
        panel.roomList:SetText("No open workshops yet.")
    else
        panel.roomList:SetText("Select a workshop above.")
    end

    if room then
        SetDropdownDisplayText(panel.joinDropdown, room.name)
    else
        SetDropdownDisplayText(panel.joinDropdown, "Select a workshop...")
    end

    local canManageWorkshop = room and GuildWorkshopTest_CanManageWorkshop(room, UnitName("player"))
    panel.closeBtn:SetShown(canManageWorkshop)
    panel.changeWorkshopBtn:SetShown(room ~= nil)
    panel.changeWorkshopBtn:ClearAllPoints()
    if canManageWorkshop then
        panel.changeWorkshopBtn:SetPoint("RIGHT", panel.closeBtn, "LEFT", -8, 0)
    else
        panel.changeWorkshopBtn:SetPoint("TOPRIGHT", -16, -10)
    end

    if room then
        panel.help:Hide()
    else
        panel.help:Show()
        panel.help:SetText("Select or create a workshop first. Once active, manage members and crafters below.")
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
        local room = GuildWorkshopTest_GetActiveRoom()
        if room and not GuildWorkshopTest_IsWorkshopFullySupported(room) then
            print("|cff00ccffGuildWorkshopTest|r " .. GuildWorkshopTest_GetUnsupportedWorkshopMessage(room))
            return
        end
        if GuildWorkshopTest_ShouldShareStock() then
            GuildWorkshopTest_RefreshLocalStock()
            print("|cff00ccffGuildWorkshopTest|r Material stock scanned and shared with the workshop.")
        elseif GuildWorkshopTest.UI then
            GuildWorkshopTest_RefreshUI()
            print("|cff00ccffGuildWorkshopTest|r Material stock refreshed.")
        end
    end)

    local scroll = CreateFrame("ScrollFrame", "GuildWorkshopTestStockScroll", panel, "UIPanelScrollFrameTemplate")
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

    local room = GuildWorkshopTest_GetActiveRoom()
    if not room then
        panel.title:SetText("Material Stock")
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetText("Select a workshop to view collaborator stock.")
        table.insert(panel.stockLines, empty)
        panel.content:SetHeight(80)
        return
    end

    if not GuildWorkshopTest_IsWorkshopFullySupported(room) then
        panel.title:SetText("Material Stock")
        panel.refreshBtn:Disable()
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetWidth(FRAME_WIDTH - 88)
        empty:SetJustifyH("LEFT")
        empty:SetText(GuildWorkshopTest_GetUnsupportedWorkshopMessage(room))
        table.insert(panel.stockLines, empty)
        panel.content:SetHeight(80)
        return
    end

    panel.title:SetText(GuildWorkshopTest_IsJewelcraftingWorkshop(room) and "Gem Stock Overview"
        or (GuildWorkshopTest_GetRoomScarceMaterialName(room) or "Material") .. " Stock")
    panel.refreshBtn:Enable()

    local crafterSingular = GuildWorkshopTest_GetRoomCrafterSingular(room)
    local crafterPlural = GuildWorkshopTest_GetCrafterLabel(GuildWorkshopTest_GetRoomProfession(room))

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
        local listing = GuildWorkshopTest_GetStockListing(counts, GuildWorkshopTest_GetRoomProfession(room))
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
                GuildWorkshopTest_AttachItemTooltip(row, function()
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
            local nameText = GuildWorkshopTest_ColorizePlayer(title)
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
    local canShare = GuildWorkshopTest_ShouldShareStock()
    if canShare then
        local personalTitle = "Your Bags + Bank"
        local bankNote = GuildWorkshopTest_GetBankStockNote and GuildWorkshopTest_GetBankStockNote()
        if bankNote then
            personalTitle = personalTitle .. " |cff888888(" .. bankNote .. ")|r"
        end
        AddSection(personalTitle, GuildWorkshopTest_GetStockCounts("personal"), "personal")
    end

    local sharedJcs = {}
    for _, jcName in ipairs(GuildWorkshopTest_GetWorkshopStockContributors(room)) do
        if not (canShare and jcName == player) then
            table.insert(sharedJcs, jcName)
        end
    end

    if #sharedJcs > 0 then
        AddSection("Shared by " .. crafterPlural, {}, "group")
        for _, jcName in ipairs(sharedJcs) do
            local report = GuildWorkshopTestDB.stock.jcReports[jcName]
            local counts = report and report.counts or {}
            AddSection(jcName, counts, "jc", { noReport = not report })
        end
    end

    AddSection("Workshop Total", GuildWorkshopTest_GetAggregatedWorkshopStock(room), "total")

    panel.content:SetHeight(math.max(400, y + 20))
end

function UI:CreateRecipesPanel()
    if GuildWorkshopTest_InitRecipeEvents then
        GuildWorkshopTest_InitRecipeEvents()
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

    panel.refreshBtn = CreateFrame("Button", "GuildWorkshopTestRecipesRefresh", panel, "SecureActionButtonTemplate, UIPanelButtonTemplate")
    panel.refreshBtn:SetSize(100, 22)
    panel.refreshBtn:SetPoint("TOPRIGHT", -16, -14)
    panel.refreshBtn:SetText("Refresh")
    panel.refreshBtn:SetScript("OnShow", function(self)
        if GuildWorkshopTest_InitRecipesRefreshButton then
            GuildWorkshopTest_InitRecipesRefreshButton(self)
        end
    end)

    local scroll = CreateFrame("ScrollFrame", "GuildWorkshopTestRecipesScroll", panel, "UIPanelScrollFrameTemplate")
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

    local room = GuildWorkshopTest_GetActiveRoom()
    if not room then
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetText("Select a workshop to view recipe coverage.")
        table.insert(panel.recipeLines, empty)
        panel.content:SetHeight(80)
        return
    end

    if not GuildWorkshopTest_IsWorkshopFullySupported(room) then
        panel.refreshBtn:Disable()
        panel.help:SetText(GuildWorkshopTest_GetUnsupportedWorkshopMessage(room))
        local empty = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        empty:SetPoint("TOPLEFT", 8, -8)
        empty:SetWidth(FRAME_WIDTH - 88)
        empty:SetJustifyH("LEFT")
        empty:SetText(GuildWorkshopTest_GetUnsupportedWorkshopMessage(room))
        table.insert(panel.recipeLines, empty)
        panel.content:SetHeight(80)
        return
    end

    panel.refreshBtn:Enable()
    local isJewelcrafting = GuildWorkshopTest_IsJewelcraftingWorkshop(room)
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
            .. string.lower(GuildWorkshopTest_GetCrafterLabel(GuildWorkshopTest_GetRoomProfession(room))) .. ".")
    end

    local contributors = GuildWorkshopTest_GetWorkshopStockContributors(room)
    local crafterPlural = GuildWorkshopTest_GetCrafterLabel(GuildWorkshopTest_GetRoomProfession(room))
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
    for _, entry in ipairs(GuildWorkshopTest_GetRecipeCoverage(room, tier)) do
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
            GuildWorkshopTest_AttachItemTooltip(nameBtn, function()
                return craft.itemId
            end)

            local crafterLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            crafterLabel:SetPoint("LEFT", nameBtn, "RIGHT", 8, 0)
            crafterLabel:SetPoint("RIGHT", -8, 0)
            crafterLabel:SetJustifyH("RIGHT")
            if hasRecipe then
                local names = {}
                for _, crafterName in ipairs(entry.jcs) do
                    table.insert(names, GuildWorkshopTest_ColorizePlayer(crafterName))
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
            GuildWorkshopTest_AttachItemTooltip(nameBtn, function()
                return gem.itemId
            end)

            local jcLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            jcLabel:SetPoint("LEFT", nameBtn, "RIGHT", 8, 0)
            jcLabel:SetPoint("RIGHT", -8, 0)
            jcLabel:SetJustifyH("RIGHT")
            if hasRecipe then
                local names = {}
                for _, jcName in ipairs(entry.jcs) do
                    table.insert(names, GuildWorkshopTest_ColorizePlayer(jcName))
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
    GuildWorkshopTest_ClearDropdownItemTooltips()
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
        GuildWorkshopTest_ApplyDropdownItemTooltips(indexToItemId)
        return
    end

    if category == "PVE" then
        for _, raid in ipairs(GuildWorkshopTest_GearRaids) do
            local header = UIDropDownMenu_CreateInfo()
            header.text = raid
            header.isTitle = true
            header.notCheckable = true
            UIDropDownMenu_AddButton(header)
            buttonIndex = buttonIndex + 1

            for _, gear in ipairs(GuildWorkshopTest_GetGearByRaid(raid)) do
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
            GuildWorkshopTest_ApplyDropdownItemTooltips(indexToItemId)
            return
        end

        for _, gear in ipairs(GuildWorkshopTest_GetGearByClass(className)) do
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

    GuildWorkshopTest_ApplyDropdownItemTooltips(indexToItemId)
end

function UI:CreateGearDropdown(name, parent, point, x, y, frameRef, width)
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint(point, parent, point, x, y)

    UIDropDownMenu_SetWidth(dropdown, width or 300)
    UIDropDownMenu_Initialize(dropdown, function()
        self:PopulateGearDropdown(dropdown, frameRef)
    end)

    SetDropdownDisplayText(dropdown, "Select gear...")
    GuildWorkshopTest_AttachDropdownTooltips(dropdown, function()
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
        GuildWorkshopTest_ClearDropdownItemTooltips()
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

        for _, category in ipairs(GuildWorkshopTest_GearCategories) do
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
        GuildWorkshopTest_ClearDropdownItemTooltips()
        local clearInfo = UIDropDownMenu_CreateInfo()
        clearInfo.text = GEAR_CLASS_PLACEHOLDER
        MarkDropdownSelection(clearInfo, not frameRef.selectedGearClass)
        clearInfo.func = function()
            frameRef.selectedGearClass = nil
            SetDropdownDisplayText(dropdown, GEAR_CLASS_PLACEHOLDER)
            self:ClearGearItemSelection(frameRef)
        end
        UIDropDownMenu_AddButton(clearInfo)

        for _, className in ipairs(GuildWorkshopTest_PvpClasses) do
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
        GuildWorkshopTest_ClearDropdownItemTooltips()
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
                local label = GuildWorkshopTest_FormatGemDropdownLabel(gem.name) or gem.name
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

        GuildWorkshopTest_ApplyDropdownItemTooltips(indexToItemId)
    end)

    SetDropdownDisplayText(dropdown, GEM_PLACEHOLDER)
    GuildWorkshopTest_AttachDropdownTooltips(dropdown, function()
        return GuildWorkshopTest_GetGemItemId(getSelected())
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
            SetDropdownDisplayText(dropdown, GuildWorkshopTest_FormatGemDropdownLabel(gemName) or gemName)
        end
    end
end

function UI:ConfigureOrderFormMode(room)
    local f = self.frame
    if not f then
        return
    end

    local isCraft = room and GuildWorkshopTest_IsHoDProfession(GuildWorkshopTest_GetRoomProfession(room))
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

    if isCraft then
        f.selectedGearCategory = nil
        f.selectedGearClass = nil
        f.selectedGear = nil
        if not f.selectedCraftCategory then
            local categories = GuildWorkshopTest_GetCraftCategories(GuildWorkshopTest_GetRoomProfession(room))
            f.selectedCraftCategory = categories[1]
        end
        if f.craftCategoryDropdown and f.selectedCraftCategory then
            SetDropdownDisplayText(f.craftCategoryDropdown, f.selectedCraftCategory)
        end
        if f.craftDropdown then
            self:PopulateCraftDropdown(f.craftDropdown, f)
        end
    else
        f.selectedCraftCategory = nil
        f.selectedCraft = nil
    end

    self:RelayoutOrderForm()
end

function UI:PopulateCraftDropdown(dropdown, frameRef)
    local room = GuildWorkshopTest_GetActiveRoom()
    if not room then
        return
    end
    local professionId = GuildWorkshopTest_GetRoomProfession(room)
    GuildWorkshopTest_ClearDropdownItemTooltips()
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
        GuildWorkshopTest_ApplyDropdownItemTooltips(indexToItemId)
        return
    end

    for _, craft in ipairs(GuildWorkshopTest_GetCraftsByCategory(professionId, category)) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = GuildWorkshopTest_FormatCraftLabel(craft)
        info.value = craft.itemId
        MarkDropdownSelection(info, frameRef.selectedCraft and frameRef.selectedCraft.itemId == craft.itemId)
        info.func = function()
            frameRef.selectedCraft = craft
            SetDropdownDisplayText(dropdown, craft.name)
            if frameRef.craftWarning then
                if GuildWorkshopTest_WorkshopHasRecipeForCraft(craft.name) then
                    frameRef.craftWarning:Hide()
                else
                    frameRef.craftWarning.text:SetText("|cffffff00Warning: Your guild has not yet obtained this recipe.|r")
                    frameRef.craftWarning:Show()
                end
            end
            self:RelayoutOrderForm()
        end
        UIDropDownMenu_AddButton(info)
        buttonIndex = buttonIndex + 1
        indexToItemId[buttonIndex] = craft.itemId
    end

    GuildWorkshopTest_ApplyDropdownItemTooltips(indexToItemId)
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
        placeRow(f.craftCategoryLabel, f.craftCategoryDropdown)
        placeRow(f.craftLabel, f.craftDropdown)
        if f.craftWarning and f.craftWarning:IsShown() then
            f.craftWarning:ClearAllPoints()
            f.craftWarning:SetPoint(
                "TOPLEFT",
                inset,
                "TOPLEFT",
                ORDER_DIALOG_FIELD_X,
                -y + ORDER_DIALOG_DROPDOWN_TEXT_INSET - ORDER_DIALOG_WARNING_GAP
            )
            y = y + ORDER_DIALOG_WARNING_HEIGHT + ORDER_DIALOG_WARNING_GAP
        end
        placeRow(f.roleLabel, f.roleDropdown)
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

    local contentBottom = y + 4 + 20
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

    local dialog = CreateFrame("Frame", "GuildWorkshopTestOrderDialog", f)
    dialog:SetSize(ORDER_DIALOG_WIDTH, ORDER_DIALOG_MIN_HEIGHT)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(f:GetFrameLevel() + 60)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:Hide()
    GuildWorkshopTest_RegisterEscapeFrame(dialog)

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

    local portrait = titleBar:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(36, 36)
    portrait:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    portrait:SetTexture(ORDER_DIALOG_MAIL_ICON)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
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
    if not GuildWorkshopTest_HasJoinedWorkshop() then
        print("|cff00ccffGuildWorkshopTest|r Select a workshop before placing an order.")
        return
    end
    local room = GuildWorkshopTest_GetActiveRoom()
    if room and not GuildWorkshopTest_IsWorkshopFullySupported(room) then
        print("|cff00ccffGuildWorkshopTest|r " .. GuildWorkshopTest_GetUnsupportedWorkshopMessage(room))
        return
    end
    if self.frame and self.frame.orderDialog then
        self:ConfigureOrderFormMode(room)
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
    if GuildWorkshopTest_IsLoggingOut and GuildWorkshopTest_IsLoggingOut() then
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
        "GuildWorkshopTestGearTypeDropdown",
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
        "GuildWorkshopTestGearClassDropdown",
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
        "GuildWorkshopTestGearDropdown",
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
    f.craftCategoryDropdown = CreateFrame("Frame", "GuildWorkshopTestCraftCategoryDropdown", inset, "UIDropDownMenuTemplate")
    f.craftCategoryDropdown:Hide()
    f.craftCategoryDropdown:SetPoint("TOPLEFT", 90, y + 8)
    UIDropDownMenu_Initialize(f.craftCategoryDropdown, function()
        local room = GuildWorkshopTest_GetActiveRoom()
        if not room then
            return
        end
        GuildWorkshopTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        info.text = CRAFT_CATEGORY_PLACEHOLDER
        info.notCheckable = true
        info.disabled = true
        UIDropDownMenu_AddButton(info)

        for _, category in ipairs(GuildWorkshopTest_GetCraftCategories(GuildWorkshopTest_GetRoomProfession(room))) do
            info = UIDropDownMenu_CreateInfo()
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

    f.craftLabel = CreateLabel(inset, "Craft:", "GameFontHighlight")
    f.craftLabel:Hide()
    f.craftDropdown = CreateFrame("Frame", "GuildWorkshopTestCraftDropdown", inset, "UIDropDownMenuTemplate")
    f.craftDropdown:Hide()
    f.craftDropdown:SetPoint("TOPLEFT", 90, y + 8)
    UIDropDownMenu_Initialize(f.craftDropdown, function()
        self:PopulateCraftDropdown(f.craftDropdown, f)
    end)
    SetDropdownDisplayText(f.craftDropdown, CRAFT_PLACEHOLDER)
    ConfigureOrderDropdown(f.craftDropdown, ORDER_DIALOG_DROPDOWN_WIDTH)
    GuildWorkshopTest_AttachDropdownTooltips(f.craftDropdown, function()
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
    f.roleDropdown = CreateFrame("Frame", "GuildWorkshopTestRoleDropdown", inset, "UIDropDownMenuTemplate")
    f.roleDropdown:SetPoint("TOPLEFT", 90, y + 8)
    UIDropDownMenu_Initialize(f.roleDropdown, function()
        GuildWorkshopTest_ClearDropdownItemTooltips()
        local info = UIDropDownMenu_CreateInfo()
        info.text = ROLE_PLACEHOLDER
        info.notCheckable = true
        info.disabled = true
        UIDropDownMenu_AddButton(info)

        for _, role in ipairs(GuildWorkshopTest_ROLES) do
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
            "GuildWorkshopTestGemDropdown" .. i,
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
    f.notesInput:SetSize(ORDER_DIALOG_DROPDOWN_WIDTH, 20)
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

    f.submitBtn = CreateFrame("Button", nil, dialog.footer, "UIPanelButtonTemplate")
    f.submitBtn:SetSize(110, 22)
    f.submitBtn:SetPoint("RIGHT", dialog.footer, "RIGHT", 0, 0)
    f.submitBtn:SetText("Submit Order")
    f.submitBtn:SetScript("OnClick", function()
        local _, err
        if f.orderFormMode == "craft" then
            _, err = GuildWorkshopTest_CreateCraftOrder(
                f.selectedCraft,
                GetNotesInputText(f.notesInput),
                f.selectedRole
            )
        else
            _, err = GuildWorkshopTest_CreateOrder(
                f.selectedGear,
                f.selectedGems,
                GetNotesInputText(f.notesInput),
                f.selectedRole
            )
        end
        if err then
            print("|cff00ccffGuildWorkshopTest|r " .. err)
        else
            print("|cff00ccffGuildWorkshopTest|r Order submitted!")
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
            for i = 1, 3 do
                f.selectedGems[i] = "None"
                SetDropdownDisplayText(f.gemDropdowns[i], GEM_PLACEHOLDER)
                self:UpdateGemRecipeWarning(i)
            end
            self:RelayoutOrderForm()
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
    if gemName == "None" or GuildWorkshopTest_WorkshopHasRecipeForGem(gemName) then
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

    local scroll = CreateFrame("ScrollFrame", "GuildWorkshopTestScroll", inset, "UIPanelScrollFrameTemplate")

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

        local itemId = GuildWorkshopTest_GetGemItemId(gemName)
        if itemId then
            local btn = CreateFrame("Button", nil, parent)
            btn:SetSize(28, 28)
            btn:SetPoint("TOPLEFT", x, y)
            btn:SetNormalTexture(GetItemIcon(itemId) or "Interface\\Icons\\Inv_misc_gem_01")

            local border = btn:CreateTexture(nil, "OVERLAY")
            border:SetTexture("Interface\\Common\\WhiteIconFrame")
            border:SetAllPoints()

            GuildWorkshopTest_AttachItemTooltip(btn, function()
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
            GuildWorkshopTest_AttachItemTooltip(labelBtn, function()
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
    return GuildWorkshopTest_GetCraftByItemId(order.itemId) ~= nil
        or GuildWorkshopTest_GetCraftByName(order.item) ~= nil
end

function UI:GetOrderRowHeight(order)
    local height = ORDER_ROW_HEIGHT + 8
    if self:IsCraftOrder(order) then
        height = height - 34
    elseif order.gems and #order.gems > 2 then
        height = height + 30
    end
    if order.notes and order.notes ~= "" then
        height = height + 14
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

    local title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(string.format(
        "%s  %s  [%s]",
        GuildWorkshopTest_ColorizePlayer(order.player, order.class),
        GuildWorkshopTest_GetRoleLabel(order.role),
        GuildWorkshopTest_GetOrderStatusLabel(order)
    ))
    title:SetWidth(contentWidth - 170)
    title:SetJustifyH("LEFT")

    local canManage = GuildWorkshopTest_CanManageOrder(order)
    local actionBtn

    if canManage and order.status ~= "completed" and order.status ~= "cancelled" then
        local btnArea = CreateFrame("Frame", nil, row)
        btnArea:SetSize(154, 20)
        btnArea:SetPoint("TOPRIGHT", -8, -8)

        if order.status == "pending" then
            actionBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            actionBtn:SetSize(84, 20)
            actionBtn:SetPoint("RIGHT", 0, 0)
            actionBtn:SetText("Pick order")
            actionBtn:SetScript("OnClick", function()
                GuildWorkshopTest_UpdateStatus(order.id, "in_progress")
                self:Refresh()
            end)
        elseif order.status == "in_progress" then
            actionBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            actionBtn:SetSize(70, 20)
            actionBtn:SetPoint("RIGHT", 0, 0)
            actionBtn:SetText("Done")
            actionBtn:SetScript("OnClick", function()
                GuildWorkshopTest_UpdateStatus(order.id, "completed")
                self:Refresh()
            end)
        end

        if actionBtn and order.status ~= "completed" then
            local downBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            downBtn:SetSize(24, 20)
            downBtn:SetPoint("RIGHT", actionBtn, "LEFT", -6, 0)
            downBtn:SetText("v")
            downBtn:SetScript("OnClick", function()
                local ok, err = GuildWorkshopTest_MoveOrder(order.id, 1)
                if not ok and err then
                    print("|cff00ccffGuildWorkshopTest|r " .. err)
                end
                self:Refresh()
            end)

            local upBtn = CreateFrame("Button", nil, btnArea, "UIPanelButtonTemplate")
            upBtn:SetSize(24, 20)
            upBtn:SetPoint("RIGHT", downBtn, "LEFT", -2, 0)
            upBtn:SetText("^")
            upBtn:SetScript("OnClick", function()
                local ok, err = GuildWorkshopTest_MoveOrder(order.id, -1)
                if not ok and err then
                    print("|cff00ccffGuildWorkshopTest|r " .. err)
                end
                self:Refresh()
            end)
        end
    end

    local gearItemId = order.itemId or GuildWorkshopTest_GetGearItemId(order.item)
    local isCraftOrder = self:IsCraftOrder(order)
    local contentTop = -28
    local contentX = 48

    local itemLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    itemLabel:SetPoint("TOPLEFT", 10, contentTop - 2)
    itemLabel:SetText(isCraftOrder and "Craft:" or "Gear:")

    if gearItemId then
        local gearIcon = CreateFrame("Button", nil, row)
        gearIcon:SetSize(28, 28)
        gearIcon:SetPoint("TOPLEFT", contentX, contentTop)
        gearIcon:SetNormalTexture(GetItemIcon(gearItemId) or "Interface\\Icons\\INV_Misc_QuestionMark")

        local borderTex = gearIcon:CreateTexture(nil, "OVERLAY")
        borderTex:SetTexture("Interface\\Common\\WhiteIconFrame")
        borderTex:SetAllPoints()

        GuildWorkshopTest_AttachItemTooltip(gearIcon, function()
            if order.itemLink then
                return order.itemLink
            end
            return gearItemId
        end)
    end

    local itemBtn = CreateFrame("Button", nil, row)
    itemBtn:SetPoint("TOPLEFT", gearItemId and (contentX + 32) or contentX, contentTop - 4)
    itemBtn:SetSize(contentWidth - (gearItemId and 120 or 88), 16)
    local itemText = itemBtn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    itemText:SetPoint("LEFT", 0, 0)
    itemText:SetJustifyH("LEFT")
    itemText:SetText(ColorizeItem(order.item or "Unknown item"))
    itemBtn:SetWidth(itemText:GetStringWidth() + 4)
    if gearItemId or order.itemLink then
        GuildWorkshopTest_AttachItemTooltip(itemBtn, function()
            if order.itemLink then
                return order.itemLink
            end
            return gearItemId
        end)
    end

    local gemsTop = contentTop - 34
    if not isCraftOrder then
        local gemsLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        gemsLabel:SetPoint("TOPLEFT", 10, gemsTop - 2)
        gemsLabel:SetText("Gems:")
        self:CreateGemIconRow(row, order, gemsTop, contentX)
    else
        local materialLabel = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        materialLabel:SetPoint("TOPLEFT", 10, gemsTop - 2)
        materialLabel:SetText("Material:")
        local materialText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        materialText:SetPoint("TOPLEFT", contentX, gemsTop - 4)
        local count = order.materialCount or 1
        local materialName = order.material or "Heart of Darkness"
        materialText:SetText(string.format("%dx %s", count, materialName))
    end

    if order.notes and order.notes ~= "" then
        local notes = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        notes:SetPoint("BOTTOMLEFT", 10, 6)
        notes:SetWidth(contentWidth - 20)
        notes:SetJustifyH("LEFT")
        notes:SetText("|cffffffffNote: " .. order.notes .. "|r")
    end

    local player = UnitName("player")
    local isOwner = order.player == player
    local room = order.roomId and GuildWorkshopTest_GetRoom(order.roomId)
    local canManageWorkshop = room and GuildWorkshopTest_CanManageWorkshop(room, player)

    if canManageWorkshop then
        local deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        deleteBtn:SetSize(60, 20)
        deleteBtn:SetPoint("TOPRIGHT", -8, -32)
        deleteBtn:SetText("Delete")
        deleteBtn:SetScript("OnClick", function()
            local ok, err = GuildWorkshopTest_DeleteOrder(order.id)
            if not ok and err then
                print("|cff00ccffGuildWorkshopTest|r " .. err)
            end
            self:Refresh()
        end)
    elseif (isOwner or canManage) and order.status == "pending" then
        local cancelBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        cancelBtn:SetSize(60, 20)
        cancelBtn:SetPoint("TOPRIGHT", -8, -32)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function()
            GuildWorkshopTest_CancelOrder(order.id)
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

function UI:Refresh()
    if not self.frame or (GuildWorkshopTest_IsLoggingOut and GuildWorkshopTest_IsLoggingOut()) then
        return
    end

    GuildWorkshopTest_ValidateActiveRoom()
    self:UpdateTabAccess()

    local room = GuildWorkshopTest_GetActiveRoom()
    if room and GuildWorkshopTest_IsPromotedJewelcrafter(room, UnitName("player")) then
        local crafterSingular = GuildWorkshopTest_GetRoomCrafterSingular(room)
        self.frame.jcLabel:SetText("|cff00ff00Workshop " .. crafterSingular .. "|r")
    else
        self.frame.jcLabel:SetText("")
    end

    if GuildWorkshopTest_HasJoinedWorkshop() and room then
        self.frame.roomLabel:SetText(string.format(
            "Workshop: |cff00ff00%s|r  |cff888888(%s)|r",
            room.name,
            GuildWorkshopTest_FormatWorkshopScope(room)
        ))
    else
        self.frame.roomLabel:SetText("|cffffcc00Select a workshop on the Workshop tab to unlock Orders, Stock and Recipes.|r")
    end

    if self.activeTab == "workshop" then
        self:RefreshWorkshopPanel()
    elseif self.activeTab == "stock" and GuildWorkshopTest_HasJoinedWorkshop() then
        self:RefreshStockPanel()
    elseif self.activeTab == "recipes" and GuildWorkshopTest_HasJoinedWorkshop() then
        self:RefreshRecipesPanel()
    end

    if self.activeTab == "orders" or self.activeTab == "completed" then
        self:LayoutQueuePanel()
    end

    self:ClearRows()
    if not self.frame.content then
        return
    end
    if self.activeTab == "orders" and GuildWorkshopTest_HasJoinedWorkshop() then
        local orders = GuildWorkshopTest_GetActiveOrders()
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
    elseif self.activeTab == "completed" and GuildWorkshopTest_HasJoinedWorkshop() then
        local orders = GuildWorkshopTest_GetCompletedOrders()
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
        print("|cffff0000GuildWorkshop refresh error:|r " .. tostring(err))
    end
end

function UI:Hide()
    SafeCloseDropdownMenus()
    self.frame:Hide()
end
