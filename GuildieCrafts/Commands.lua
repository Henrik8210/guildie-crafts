SLASH_GUILDIECRAFTS1 = "/guildiecrafts"
SLASH_GUILDIECRAFTS2 = "/gc"
SLASH_GUILDIECRAFTS3 = "/gw"

SlashCmdList["GUILDIECRAFTS"] = function(msg)
    msg = string.lower(strtrim(msg or ""))

    if msg == "stock" then
        GuildieCrafts_RefreshLocalStock()
        print("|cff00ccffGuildie Crafts|r Material stock refreshed for " .. UnitName("player") .. ".")
        return
    end

    if msg == "sync" then
        if IsInGuild() then
            GuildieCrafts.Sync:RequestSync()
            print("|cff00ccffGuildie Crafts|r Requested sync from guild.")
        else
            print("|cff00ccffGuildie Crafts|r You are not in a guild.")
        end
        return
    end

    if msg:match("^debug") then
        if GuildieCrafts.Debug then
            GuildieCrafts.Debug:HandleCommand(strtrim(msg:sub(7)))
        else
            print("|cffff0000Guildie Crafts|r Debug module not loaded.")
        end
        return
    end

    if msg:match("^join ") then
        local roomId = strtrim(msg:sub(6))
        local _, err = GuildieCrafts_JoinWorkshop(roomId)
        if err then
            print("|cff00ccffGuildie Crafts|r " .. err)
        else
            GuildieCrafts_RefreshUI()
        end
        return
    end

    if GuildieCrafts_EnsureUI() then
        GuildieCrafts.UI:Toggle()
    end
end
