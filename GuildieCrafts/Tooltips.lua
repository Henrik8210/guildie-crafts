GuildieCrafts = GuildieCrafts or {}
GuildieCrafts._loggingOut = false

function GuildieCrafts_IsLoggingOut()
    return GuildieCrafts._loggingOut == true
end

function GuildieCrafts_PrepareForLogout()
    GuildieCrafts._loggingOut = true

    if UISpecialFrames then
        for i = #UISpecialFrames, 1, -1 do
            local entry = UISpecialFrames[i]
            if entry == "GuildieCraftsFrame" or entry == "GuildieCraftsOrderDialog" then
                tremove(UISpecialFrames, i)
            end
        end
    end

    local ui = GuildieCrafts.UI
    if not ui or not ui.frame then
        return
    end

    local f = ui.frame
    f:SetScript("OnHide", nil)
    f:SetScript("OnMouseDown", nil)

    if f.queueInset then
        f.queueInset:SetScript("OnMouseDown", nil)
    end
    if f.workshopPanel then
        f.workshopPanel:SetScript("OnMouseDown", nil)
    end
    if f.stockPanel then
        f.stockPanel:SetScript("OnMouseDown", nil)
    end
    if f.recipesPanel then
        f.recipesPanel:SetScript("OnMouseDown", nil)
    end

    if f.orderDialog then
        f.orderDialog:SetScript("OnHide", nil)
        if f.orderDialog.panel then
            f.orderDialog.panel:SetScript("OnMouseDown", nil)
        end
        if f.orderDialog.inset then
            f.orderDialog.inset:SetScript("OnMouseDown", nil)
        end
        if f.orderDialogOverlay then
            f.orderDialogOverlay:SetScript("OnMouseDown", nil)
            f.orderDialogOverlay:Hide()
        end
        f.orderDialog:Hide()
    end

    f:Hide()
end

function GuildieCrafts_ShowItemTooltip(owner, itemId, anchor)
    if not itemId or not owner then
        return
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. itemId)
    if GameTooltip.SetClampedToScreen then
        GameTooltip:SetClampedToScreen(true)
    end
    GameTooltip:Show()
end

function GuildieCrafts_ShowLinkTooltip(owner, link, anchor)
    if not link or not owner then
        return
    end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(link)
    if GameTooltip.SetClampedToScreen then
        GameTooltip:SetClampedToScreen(true)
    end
    GameTooltip:Show()
end

function GuildieCrafts_HideTooltip()
    GameTooltip:Hide()
end

local function ResolveItemLink(itemIdOrLink)
    if not itemIdOrLink then
        return nil
    end

    if type(itemIdOrLink) == "string" then
        if itemIdOrLink:find("|Hitem:") then
            return itemIdOrLink
        end
        local itemId = tonumber(itemIdOrLink:match("item:(%d+)"))
        if itemId then
            itemIdOrLink = itemId
        else
            return nil
        end
    end

    if type(itemIdOrLink) ~= "number" or itemIdOrLink <= 0 then
        return nil
    end

    local _, link = GetItemInfo(itemIdOrLink)
    if link then
        return link
    end

    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetHyperlink("item:" .. itemIdOrLink)
    GameTooltip:Hide()
    _, link = GetItemInfo(itemIdOrLink)
    return link
end

function GuildieCrafts_InsertChatItemLink(itemIdOrLink)
    local link = ResolveItemLink(itemIdOrLink)
    if not link then
        return false
    end

    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then
        return true
    end

    local editBox = ChatFrame1EditBox
    if editBox and editBox:IsShown() then
        editBox:Insert(link)
        editBox:SetFocus()
        return true
    end

    if ChatFrame_OpenChat then
        ChatFrame_OpenChat("")
        editBox = ChatFrame1EditBox
        if editBox then
            editBox:Insert(link)
            editBox:SetFocus()
            return true
        end
    end

    return false
end

local function IsShiftChatLinkClick(button)
    if button ~= "LeftButton" and button ~= "LeftButtonUp" then
        return false
    end
    if IsModifiedClick and IsModifiedClick("CHATLINK") then
        return true
    end
    if IsShiftKeyDown then
        return IsShiftKeyDown()
    end
    return false
end

local function IsDressUpClick(button)
    if button ~= "LeftButton" and button ~= "LeftButtonUp" then
        return false
    end
    if IsModifiedClick and IsModifiedClick("DRESSUP") then
        return true
    end
    if IsControlKeyDown then
        return IsControlKeyDown()
    end
    return false
end

function GuildieCrafts_HandleItemClick(itemIdOrLink, button)
    if button ~= "LeftButton" and button ~= "LeftButtonUp" then
        return false
    end

    local dressUp = IsDressUpClick(button)
    local chatLink = IsShiftChatLinkClick(button)
    if not dressUp and not chatLink then
        return false
    end

    local link = ResolveItemLink(itemIdOrLink)
    if not link then
        return false
    end

    if HandleModifiedItemClick and HandleModifiedItemClick(link) then
        return true
    end

    if dressUp then
        if DressUpItemLink then
            DressUpItemLink(link)
            return true
        end
        if ShowUIPanel and DressUpFrame then
            ShowUIPanel(DressUpFrame)
            if DressUpModel and DressUpModel.TryOn then
                DressUpModel:TryOn(link)
                return true
            end
        end
    end

    if chatLink then
        return GuildieCrafts_InsertChatItemLink(itemIdOrLink)
    end

    return false
end

function GuildieCrafts_RegisterEscapeFrame(frame)
    if not frame or not UISpecialFrames then
        return
    end
    if GuildieCrafts.Debug and GuildieCrafts.Debug.ShouldSkipUISpecialFrames
        and GuildieCrafts.Debug:ShouldSkipUISpecialFrames() then
        return
    end

    local name = frame.GetName and frame:GetName()
    if not name or name == "" then
        return
    end

    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == name then
            return
        end
    end

    tinsert(UISpecialFrames, name)
end

function GuildieCrafts_GetGemItemId(gemName)
    if not gemName or gemName == "None" then
        return nil
    end
    local gem = GuildieCrafts_GemByName and GuildieCrafts_GemByName[gemName]
    return gem and gem.itemId
end

function GuildieCrafts_ExtractItemLink(text)
    if not text or text == "" then
        return nil
    end
    local link = text:match("(|c.-|Hitem:[%-%d:]+|h%[.-]|h|r)")
    if link then
        return link
    end
    link = text:match("(|Hitem:[%-%d:]+|h%[.-]|h)")
    if link then
        return link
    end
    local itemId = text:match("^item:(%d+)")
    if itemId then
        return "item:" .. itemId
    end
    return nil
end

function GuildieCrafts_ExtractItemId(text)
    local link = GuildieCrafts_ExtractItemLink(text)
    if not link then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

function GuildieCrafts_GetItemDisplayText(text)
    local link = GuildieCrafts_ExtractItemLink(text)
    if link then
        local name = GetItemInfo(link)
        if name then
            return name
        end
    end
    return text
end

function GuildieCrafts_TooltipsInit()
    GuildieCrafts.itemLinkTarget = nil
end

function GuildieCrafts_AttachItemTooltip(frame, getLinkFn)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
        local link = getLinkFn(self)
        if link then
            if type(link) == "number" then
                GuildieCrafts_ShowItemTooltip(self, link)
            else
                GuildieCrafts_ShowLinkTooltip(self, link)
            end
        end
    end)
    frame:SetScript("OnLeave", GuildieCrafts_HideTooltip)
    frame:SetScript("OnMouseUp", function(self, button)
        GuildieCrafts_HandleItemClick(getLinkFn(self), button)
    end)
end

function GuildieCrafts_ClearDropdownItemTooltips(level)
    level = level or UIDROPDOWNMENU_MENU_LEVEL or 1
    local maxButtons = UIDROPDOWNMENU_MAXBUTTONS or 32
    if UIDropDownMenu_GetNumberOfButtons then
        maxButtons = UIDropDownMenu_GetNumberOfButtons(level) or maxButtons
    end

    for i = 1, maxButtons do
        local button = _G["DropDownList" .. level .. "Button" .. i]
        if button then
            button.GuildieCraftsItemId = nil
        end
    end
end

function GuildieCrafts_AttachDropdownItemButton(itemId, buttonIndex)
    if not itemId or itemId <= 0 or not buttonIndex then
        return
    end

    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local button = _G["DropDownList" .. level .. "Button" .. buttonIndex]
    if not button then
        return
    end

    button.GuildieCraftsItemId = itemId
    button:SetScript("OnEnter", function(self)
        if UIDropDownMenuButton_OnEnter then
            UIDropDownMenuButton_OnEnter(self)
        end
        local linkedItemId = self.GuildieCraftsItemId
        if linkedItemId
            and type(self.value) == "number"
            and self.value > 0
            and self.value == linkedItemId then
            GuildieCrafts_ShowItemTooltip(self, linkedItemId, "ANCHOR_RIGHT")
        end
    end)
    button:SetScript("OnLeave", function(self)
        GuildieCrafts_HideTooltip()
        if UIDropDownMenuButton_OnLeave then
            UIDropDownMenuButton_OnLeave(self)
        end
    end)
    button:SetScript("OnMouseUp", function(self, mouseButton)
        local linkedItemId = self.GuildieCraftsItemId
        if linkedItemId
            and type(self.value) == "number"
            and self.value > 0
            and self.value == linkedItemId then
            GuildieCrafts_HandleItemClick(linkedItemId, mouseButton)
        end
    end)
end

function GuildieCrafts_ApplyDropdownItemTooltips(indexToItemId)
    if not indexToItemId then
        return
    end

    local level = UIDROPDOWNMENU_MENU_LEVEL or 1
    local function apply()
        GuildieCrafts_ClearDropdownItemTooltips(level)
        for index, itemId in pairs(indexToItemId) do
            GuildieCrafts_AttachDropdownItemButton(itemId, index)
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, apply)
    else
        apply()
    end
end

function GuildieCrafts_AttachDropdownTooltips(dropdown, getItemIdFn)
    local button = _G[dropdown:GetName() .. "Button"]
    if button then
        GuildieCrafts_AttachItemTooltip(button, function()
            return getItemIdFn()
        end)
    end
end

function GuildieCrafts_HookDropdownMenuTooltips()
    -- Per-item tooltips are attached when each gear/gem dropdown opens.
end
