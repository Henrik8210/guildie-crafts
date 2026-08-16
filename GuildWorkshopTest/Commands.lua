SLASH_GUILDWORKSHOPTEST1 = "/gwtest"
SLASH_GUILDWORKSHOPTEST2 = "/gwt"
SLASH_GUILDWORKSHOPTEST3 = "/gwtt"

SlashCmdList["GUILDWORKSHOPTEST"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "stock" then
        GuildWorkshopTest_RefreshLocalStock()
        print("|cff00ccffGuildWorkshopTest|r Material stock refreshed for " .. UnitName("player") .. ".")
        return
    end

    if msg == "sync" then
        if IsInGuild() then
            GuildWorkshopTest.Sync:RequestSync()
            print("|cff00ccffGuildWorkshopTest|r Requested sync from guild.")
        else
            print("|cff00ccffGuildWorkshopTest|r You are not in a guild.")
        end
        return
    end

    if msg:match("^debug") then
        if GuildWorkshopTest.Debug then
            GuildWorkshopTest.Debug:HandleCommand(strtrim(msg:sub(7)))
        else
            print("|cffff0000GuildWorkshopTest|r Debug module not loaded.")
        end
        return
    end

    if msg:match("^join ") then
        local roomId = strtrim(msg:sub(6))
        local _, err = GuildWorkshopTest_JoinWorkshop(roomId)
        if err then
            print("|cff00ccffGuildWorkshopTest|r " .. err)
        else
            print("|cff00ccffGuildWorkshopTest|r Selected workshop.")
            GuildWorkshopTest_RefreshUI()
        end
        return
    end

    if GuildWorkshopTest_EnsureUI() then
        GuildWorkshopTest.UI:Toggle()
    end
end
