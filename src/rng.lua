BD.rng = {}

local function hash(key)
    if type(pseudohash) == "function" then return pseudohash(tostring(key)) end
    local value = 0
    local text = tostring(key)
    for index = 1, #text do
        value = (value * 31 + text:byte(index)) % 2147483647
    end
    return value / 2147483647
end

function BD.rng.int(key, maximum)
    maximum = math.floor(tonumber(maximum) or 1)
    if maximum <= 1 then return 1 end
    local value = hash(key)
    local result = math.floor(value * maximum) + 1
    if result < 1 then result = 1 end
    if result > maximum then result = maximum end
    return result
end

function BD.rng.weighted(entries, key)
    local total = 0
    for _, entry in ipairs(entries or {}) do
        total = total + math.max(0, tonumber(entry.weight) or 0)
    end
    if total <= 0 then return nil end

    local roll = BD.rng.int(key, total)
    local current = 0
    for _, entry in ipairs(entries) do
        current = current + math.max(0, tonumber(entry.weight) or 0)
        if roll <= current then return entry end
    end
    return entries[#entries]
end

function BD.rng.shuffle(list, key)
    for index = #list, 2, -1 do
        local other = BD.rng.int(tostring(key) .. ":" .. tostring(index), index)
        list[index], list[other] = list[other], list[index]
    end
    return list
end

function BD.rng.id(seed, guest, timestamp)
    return string.format(
        "%s-%s-%s-%s",
        tostring(seed or "seed"),
        tostring(guest or "guest"),
        tostring(timestamp or 0),
        tostring(hash(tostring(seed) .. tostring(guest) .. tostring(timestamp)))
    )
end
