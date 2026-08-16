GuildWorkshop = GuildWorkshop or {}
local Debug = {}
GuildWorkshop.Debug = Debug

local function Settings()
    GuildWorkshopDB.settings = GuildWorkshopDB.settings or {}
    return GuildWorkshopDB.settings
end

function Debug:IsEnabled()
    return Settings().debugTaint == true
end

function Debug:Log(msg)
    if self:IsEnabled() then
        print("|cff00ccffGuildWorkshop Debug|r " .. tostring(msg))
    end
end

function Debug:GetLogPathHint()
    local account = GetRealmName and (GetRealmName() .. "\\") or ""
    return "World of Warcraft\\_anniversary_\\Logs\\FrameXML.log (search for 'GuildWorkshop' or 'taint')"
end

function Debug:EnableTaintLog()
    Settings().debugTaint = true
    if SetCVar then
        SetCVar("taintLog", "1")
    end
    print("|cff00ccffGuild Workshop|r Taint debug enabled.")
    print("  1. /reload")
    print("  2. Use GuildWorkshop normally (open UI, use dropdowns, place order, etc.)")
    print("  3. Try to log out")
    print("  4. Exit WoW completely, then open:")
    print("     " .. self:GetLogPathHint())
end

function Debug:DisableTaintLog()
    Settings().debugTaint = false
    if SetCVar then
        SetCVar("taintLog", "0")
    end
    print("|cff00ccffGuild Workshop|r Taint debug disabled.")
end

function Debug:DumpState()
    print("|cff00ccffGuild Workshop|r Taint state snapshot:")
    print("  addon execution secure: " .. (issecure() and "yes" or "NO (tainted)"))
    print("  loggingOut flag: " .. tostring(GuildWorkshop._loggingOut))
    print("  debugTaint: " .. tostring(Settings().debugTaint))
    print("  taintLog CVar: " .. tostring(GetCVar and GetCVar("taintLog") or "?"))
    print("  bisect.noDismiss: " .. tostring(Settings().debugBisectNoDismiss))
    print("  bisect.noDropdownHide: " .. tostring(Settings().debugBisectNoDropdownHide))
    print("  bisect.noUISpecial: " .. tostring(Settings().debugBisectNoUISpecial))

    if CloseDropDownMenus then
        local ok, err = pcall(function()
            return issecurevariable("CloseDropDownMenus")
        end)
        if ok then
            print("  CloseDropDownMenus global secure: " .. tostring(err))
        end
    end

    for i = 1, 2 do
        local list = _G["DropDownList" .. i]
        if list and list.IsShown and list:IsShown() then
            print("  DropDownList" .. i .. " is visible")
        end
    end

    print("  Log file: " .. self:GetLogPathHint())
end

function Debug:ShouldSkipDropdownDismiss()
    return Settings().debugBisectNoDismiss == true
end

function Debug:ShouldSkipDropdownHide()
    return Settings().debugBisectNoDropdownHide == true
end

function Debug:ShouldSkipUISpecialFrames()
    return Settings().debugBisectNoUISpecial == true
end

local BISECT_HELP = {
    nodismiss = "Disable click-to-dismiss dropdown layers.",
    nodropdownhide = "Stop hiding DropDownList frames (test CloseDropDownMenus path).",
    nouspecial = "Do not register frames in UISpecialFrames (requires /reload).",
    reset = "Clear all bisect flags.",
}

function Debug:SetBisect(flag, enabled)
    flag = string.lower(flag or "")
    if flag == "reset" then
        Settings().debugBisectNoDismiss = nil
        Settings().debugBisectNoDropdownHide = nil
        Settings().debugBisectNoUISpecial = nil
        print("|cff00ccffGuild Workshop|r Bisect flags cleared. /reload recommended.")
        return
    end

    local key
    if flag == "nodismiss" then
        key = "debugBisectNoDismiss"
    elseif flag == "nodropdownhide" then
        key = "debugBisectNoDropdownHide"
    elseif flag == "nouspecial" then
        key = "debugBisectNoUISpecial"
    else
        print("|cff00ccffGuild Workshop|r Unknown bisect flag. Options:")
        for name, help in pairs(BISECT_HELP) do
            print("  " .. name .. " — " .. help)
        end
        return
    end

    Settings()[key] = enabled ~= false
    print("|cff00ccffGuild Workshop|r Bisect " .. flag .. " = " .. tostring(Settings()[key]))
    if flag == "nouspecial" then
        print("  /reload required for this test.")
    end
end

function Debug:HandleCommand(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "" or msg == "help" then
        print("|cff00ccffGuildWorkshop Debug|r commands:")
        print("  /gor debug taint on   — enable CVar taintLog + addon tracing")
        print("  /gor debug taint off  — disable taint logging")
        print("  /gor debug dump       — print current taint/bisect state")
        print("  /gor debug bisect <flag> [off] — isolate subsystems (see help below)")
        print("  /gor debug bisect     — list bisect flags")
        return
    end

    if msg == "taint on" then
        self:EnableTaintLog()
        return
    end
    if msg == "taint off" then
        self:DisableTaintLog()
        return
    end
    if msg == "dump" then
        self:DumpState()
        return
    end

    if msg == "bisect" then
        for name, help in pairs(BISECT_HELP) do
            print("  " .. name .. " — " .. help)
        end
        return
    end

    local bisectFlag, bisectOff = msg:match("^bisect%s+(%S+)(%s+off)?$")
    if bisectFlag then
        self:SetBisect(bisectFlag, bisectOff == nil)
        return
    end

    print("|cff00ccffGuild Workshop|r Unknown debug command. Try /gor debug help")
end
