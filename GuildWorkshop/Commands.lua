SLASH_GUILDWORKSHOP1 = "/guildworkshop"
SLASH_GUILDWORKSHOP2 = "/gw"
SLASH_GUILDWORKSHOP3 = "/guildwork"

SlashCmdList["GUILDWORKSHOP"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "stock" then
        GuildWorkshop_RefreshLocalStock()
        print("|cff00ccffGuild Workshop|r Material stock refreshed for " .. UnitName("player") .. ".")
        return
    end

    if msg == "sync" then
        if IsInGuild() then
            GuildWorkshop.Sync:RequestSync()
            print("|cff00ccffGuild Workshop|r Requested sync from guild.")
        else
            print("|cff00ccffGuild Workshop|r You are not in a guild.")
        end
        return
    end

    if msg:match("^debug") then
        if GuildWorkshop.Debug then
            GuildWorkshop.Debug:HandleCommand(strtrim(msg:sub(7)))
        else
            print("|cffff0000Guild Workshop|r Debug module not loaded.")
        end
        return
    end

    if msg:match("^join ") then
        local roomId = strtrim(msg:sub(6))
        local _, err = GuildWorkshop_JoinWorkshop(roomId)
        if err then
            print("|cff00ccffGuild Workshop|r " .. err)
        else
            print("|cff00ccffGuild Workshop|r Selected workshop.")
            GuildWorkshop_RefreshUI()
        end
        return
    end

    if GuildWorkshop_EnsureUI() then
        GuildWorkshop.UI:Toggle()
    end
end
