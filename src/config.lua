BD.config = {}
BD.config.card_options = { 4, 6, 8, 10, 12, 14, 16, 18, 20 }
BD.config.pair_options = BD.config.card_options
BD.config.second_options = { 10, 15, 20, 30, 45, 60 }
BD.config.default_cards = 10
BD.config.default_seconds = 20
BD.config.default_blind = false
BD.config.default_reverse = false

local function even_in_range(value, fallback)
    value = tonumber(value) or fallback
    value = math.floor(value)
    if value < 2 then value = fallback end
    if value % 2 == 1 then value = value - 1 end
    if value < 2 then value = 2 end
    if value > 40 then value = 40 end
    return value
end

local function seconds_in_range(value, fallback)
    value = tonumber(value) or fallback
    value = math.floor(value)
    if value < 5 then value = fallback end
    if value > 120 then value = 120 end
    return value
end

function BD.config.get_default_cards()
    return BD.config.default_cards
end

function BD.config.get_pairs()
    return even_in_range(MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.draft_pairs, BD.config.get_default_cards())
end

function BD.config.get_seconds()
    return seconds_in_range(
        MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.draft_pick_seconds,
        BD.config.default_seconds
    )
end

function BD.config.get_blind()
    return MP and MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.draft_blind == true
end

function BD.config.get_reverse()
    return MP and MP.LOBBY and MP.LOBBY.config and MP.LOBBY.config.draft_reverse == true
end

function BD.config.apply()
    if not MP or not MP.LOBBY or not MP.LOBBY.config then return end
    MP.LOBBY.config.draft_pairs = even_in_range(MP.LOBBY.config.draft_pairs, BD.config.get_default_cards())
    MP.LOBBY.config.draft_pick_seconds = seconds_in_range(
        MP.LOBBY.config.draft_pick_seconds,
        BD.config.default_seconds
    )
    MP.LOBBY.config.draft_blind = MP.LOBBY.config.draft_blind == true
    MP.LOBBY.config.draft_reverse = MP.LOBBY.config.draft_reverse == true
end

function BD.config.option_index(options, value)
    value = tonumber(value)
    for index, option in ipairs(options) do
        if option == value then return index end
    end
    return 1
end

function BD.config.install()
    if BD.config.installed then return end
    BD.config.installed = true
    BD.config.apply()
    local reset_ref = MP.reset_lobby_config
    if type(reset_ref) == "function" then
        MP.reset_lobby_config = function(persist)
            reset_ref(persist)
            BD.config.apply()
        end
    end
end