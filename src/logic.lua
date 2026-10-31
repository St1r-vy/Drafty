BD.logic = {}

local function profile_all_unlocked()
    local profile = G and G.PROFILES and G.SETTINGS and G.PROFILES[G.SETTINGS.profile]
    return profile and profile.all_unlocked == true
end

function BD.logic.is_legendary(center)
    return center and center.set == "Joker" and center.rarity == 4
end

local function exclusions(key, center)
    return center
        and center.set == "Joker"
        and not BD.logic.is_legendary(center)
        and type(key) == "string"
        and not center.omit
        and not center.hidden
end

function BD.logic.get_eligible()
    local result = {}
    local all_unlocked = profile_all_unlocked()
    local banned = (G and G.GAME and G.GAME.banned_keys) or {}
    for key, center in pairs((G and G.P_CENTERS) or {}) do
        if exclusions(key, center) and not banned[key] then
            local unlocked = center.unlocked ~= false or all_unlocked
            local excluded = false
            if MP.should_exclude_from_pool then
                local ok, value = pcall(MP.should_exclude_from_pool, center)
                if ok then excluded = value == true end
            end
            if unlocked and not excluded then result[#result + 1] = key end
        end
    end
    table.sort(result)
    return result
end

function BD.logic.intersect(first, second)
    local second_set = {}
    for _, key in ipairs(second or {}) do second_set[key] = true end
    local result = {}
    for _, key in ipairs(first or {}) do
        if second_set[key] then result[#result + 1] = key end
    end
    table.sort(result)
    return result
end

local function set_candidates(shared_set, used, minimum)
    local candidates = {}
    for _, set in ipairs(BD.draft_sets or {}) do
        local keys, seen = {}, {}
        for _, key in ipairs(set.keys or {}) do
            if shared_set[key] and not used[key] and not seen[key] then
                seen[key] = true
                keys[#keys + 1] = key
            end
        end
        if #keys >= minimum then
            candidates[#candidates + 1] = {
                id = set.id,
                weight = tonumber(set.weight) or 0,
                keys = keys,
            }
        end
    end
    return candidates
end

function BD.logic.build_category_pairs(shared, count, draft_id, start_side)
    local shared_set = {}
    for _, key in ipairs(shared or {}) do shared_set[key] = true end

    local used, selected = {}, {}
    local first_side = start_side or "host"

    for round = 1, count do
        local candidates = set_candidates(shared_set, used, 4)
        local set
        if #candidates > 0 then
            set = BD.rng.weighted(candidates, tostring(draft_id) .. ":set:" .. tostring(round)) or candidates[1]
        else
            local keys = {}
            for _, key in ipairs(shared or {}) do
                if not used[key] then keys[#keys + 1] = key end
            end
            if #keys < 4 then return nil end
            set = { id = "mixed", weight = 1, keys = keys }
        end

        local keys = {}
        for _, key in ipairs(set.keys) do keys[#keys + 1] = key end
        BD.rng.shuffle(keys, tostring(draft_id) .. ":keys:" .. tostring(round))
        for index = 1, 4 do used[keys[index]] = true end

        local side = first_side
        local other = BD.other(side)

        local first = { keys[1], keys[2] }
        first.side = side
        first.round = round
        first.category = set.id
        local second = { keys[3], keys[4] }
        second.side = other
        second.round = round
        second.category = set.id

        selected[#selected + 1] = first
        selected[#selected + 1] = second
    end

    return selected
end

function BD.logic.ban_legendaries()
    if not G or not G.GAME then return end
    G.GAME.banned_keys = G.GAME.banned_keys or {}
    for key, center in pairs(G.P_CENTERS or {}) do
        if BD.logic.is_legendary(center) then G.GAME.banned_keys[key] = true end
    end
end

function BD.logic.capture_base_bans()
    if not G or not G.GAME then return end
    if not G.GAME.bd_base_banned then
        local copy = {}
        for key, value in pairs(G.GAME.banned_keys or {}) do
            if value then copy[key] = true end
        end
        G.GAME.bd_base_banned = copy
    end
    BD.logic.ban_legendaries()
end

function BD.logic.apply_bans(allowed_keys)
    if not G or not G.GAME then return end
    local allowed = {}
    for _, key in ipairs(allowed_keys or {}) do allowed[key] = true end
    local base = G.GAME.bd_base_banned or {}
    G.GAME.banned_keys = G.GAME.banned_keys or {}
    for key, center in pairs(G.P_CENTERS or {}) do
        if center.set == "Joker" then
            if BD.logic.is_legendary(center) then
                G.GAME.banned_keys[key] = true
            elseif not allowed[key] then
                G.GAME.banned_keys[key] = true
            elseif not base[key] then
                G.GAME.banned_keys[key] = nil
            end
        end
    end
end

function BD.logic.restore_bans()
    BD.logic.ban_legendaries()
    local pool = G and G.GAME and G.GAME.bd_draft_pool
    if type(pool) == "table" and #pool > 0 then
        BD.logic.apply_bans(pool)
    end
end

function BD.logic.set_local_pool(keys)
    if not G or not G.GAME then return end
    local pool = {}
    for _, key in ipairs(keys or {}) do
        local center = G.P_CENTERS[key]
        if center and not BD.logic.is_legendary(center) then pool[#pool + 1] = key end
    end
    G.GAME.bd_draft_pool = pool
    BD.logic.apply_bans(pool)
end

function BD.logic.has_filter()
    return BD.in_mp()
        and G
        and G.GAME
        and type(G.GAME.bd_draft_pool) == "table"
        and #G.GAME.bd_draft_pool > 0
end

local function key_available_now(key)
    if not G or not G.GAME then return true end
    local center = G.P_CENTERS and G.P_CENTERS[key]
    if not center or BD.logic.is_legendary(center) then return false end
    if G.GAME.used_jokers and G.GAME.used_jokers[key] then
        local showman = SMODS and type(SMODS.showman) == "function" and SMODS.showman(key)
        if not showman then return false end
    end
    local flags = G.GAME.pool_flags or {}
    if center.no_pool_flag and flags[center.no_pool_flag] then return false end
    if center.yes_pool_flag and not flags[center.yes_pool_flag] then return false end
    if SMODS and type(SMODS.add_to_pool) == "function" then
        local ok, value = pcall(SMODS.add_to_pool, center, { source = "draft" })
        if ok and value == false then return false end
    end
    return true
end

function BD.logic.filter_pool(pool)
    local own = G.GAME.bd_draft_pool
    local allowed = {}
    for _, key in ipairs(own) do allowed[key] = true end
    local filtered = {}
    for _, key in ipairs(pool or {}) do
        local center = G.P_CENTERS[key]
        if allowed[key] and not BD.logic.is_legendary(center) then
            filtered[#filtered + 1] = key
        end
    end
    if #filtered == 0 then
        local fallback = {}
        for _, key in ipairs(own) do
            if key_available_now(key) then fallback[#fallback + 1] = key end
        end
        if #fallback == 0 then
            for _, key in ipairs(own) do
                local center = G.P_CENTERS[key]
                if not BD.logic.is_legendary(center) then fallback[#fallback + 1] = key end
            end
        end
        filtered = fallback
    end
    return filtered
end

function BD.logic.finalize(data)
    local host_keys, guest_keys = {}, {}
    local pairs_by_index = data.pairs or {}
    for _, pick in ipairs(data.picks or {}) do
        local pair = pairs_by_index[pick.pair]
        local choice = tonumber(pick.choice)
        local other_key = pair and choice and pair[3 - choice] or nil
        if pick.player == "host" then
            if pick.key then host_keys[#host_keys + 1] = pick.key end
            if other_key then guest_keys[#guest_keys + 1] = other_key end
        elseif pick.player == "guest" then
            if pick.key then guest_keys[#guest_keys + 1] = pick.key end
            if other_key then host_keys[#host_keys + 1] = other_key end
        end
    end
    data.host_keys = host_keys
    data.guest_keys = guest_keys
    return host_keys, guest_keys
end

function BD.logic.pool_for(data, side, eligible)
    if not data or not side then return {} end
    if not data.reverse_draft then return data[side .. "_keys"] or {} end

    local excluded = {}
    for _, key in ipairs(data[BD.other(side) .. "_keys"] or {}) do
        excluded[key] = true
    end

    local keys = {}
    for _, key in ipairs(eligible or {}) do
        if not excluded[key] then keys[#keys + 1] = key end
    end
    return keys
end