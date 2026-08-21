SLASH_GUILDIECRAFTSTEST1 = "/gwtest"
SLASH_GUILDIECRAFTSTEST2 = "/gwt"
SLASH_GUILDIECRAFTSTEST3 = "/gwtt"

SlashCmdList["GUILDIECRAFTSTEST"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "stock" then
        GuildieCraftsTest_RefreshLocalStock()
        print("|cff00ccffGuildieCraftsTest|r Material stock refreshed for " .. UnitName("player") .. ".")
        return
    end

    if msg == "sync" then
        if IsInGuild() then
            GuildieCraftsTest.Sync:RequestSync()
            print("|cff00ccffGuildieCraftsTest|r Requested sync from guild.")
        else
            print("|cff00ccffGuildieCraftsTest|r You are not in a guild.")
        end
        return
    end

    if msg:match("^debug") then
        if GuildieCraftsTest.Debug then
            GuildieCraftsTest.Debug:HandleCommand(strtrim(msg:sub(7)))
        else
            print("|cffff0000GuildieCraftsTest|r Debug module not loaded.")
        end
        return
    end

    if msg:match("^join ") then
        local roomId = strtrim(msg:sub(6))
        local _, err = GuildieCraftsTest_JoinWorkshop(roomId)
        if err then
            print("|cff00ccffGuildieCraftsTest|r " .. err)
        else
            GuildieCraftsTest_RefreshUI()
        end
        return
    end

    if GuildieCraftsTest_EnsureUI() then
        GuildieCraftsTest.UI:Toggle()
    end
end
