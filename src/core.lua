BD = BD or {}

function BD.log(message)
    local text = "[BalatroDraft] " .. tostring(message)
    if sendInfoMessage then
        sendInfoMessage(text, BD.MOD_ID)
    else
        print(text)
    end
end

function BD.warn(message)
    local text = "[BalatroDraft] " .. tostring(message)
    if sendWarnMessage then
        sendWarnMessage(text, BD.MOD_ID)
    else
        print(text)
    end
end

function BD.in_mp()
    return MP and MP.LOBBY and MP.LOBBY.code ~= nil
end

function BD.is_draft_ruleset()
    if not MP or not MP.LOBBY or not MP.LOBBY.config then return false end
    return MP.LOBBY.config.ruleset == "ruleset_mp_draft"
end

function BD.username(side)
    if not MP or not MP.LOBBY then return side == "guest" and "Guest" or "Host" end
    local role = side or (MP.LOBBY.is_host and "host" or "guest")
    local player = MP.LOBBY[role]
    return (player and player.username) or MP.LOBBY.username or (role == "guest" and "Guest" or "Host")
end

function BD.other(side)
    return side == "host" and "guest" or "host"
end

function BD.loc(key)
    if type(localize) ~= "function" then return tostring(key) end
    local ok, value = pcall(localize, key)
    if ok and value then return value end
    return tostring(key)
end

function BD.format(key, values)
    local text = BD.loc(key)
    for name, value in pairs(values or {}) do
        local replacement = tostring(value)
        text = text:gsub("#" .. tostring(name) .. "#", function() return replacement end)
    end
    return text
end
