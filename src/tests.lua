BD.tests = {}

local function check(value, message)
    if not value then error(message or "assertion failed", 2) end
end

function BD.tests.run()
    if BD.tests.ran then return end
    BD.tests.ran = true
    local previous_sets = BD.draft_sets
    local old_data, old_remaining = BD.state.data, BD.state.remaining
    local previous_role = BD.state.role
    local ok, err = pcall(function()
        check(BD.config.get_pairs() % 2 == 0, "pair count must be even")
        check(BD.config.get_seconds() >= 5, "timer must be positive")

        local set_weight, set_keys = 0, {}
        for _, set in ipairs(BD.draft_sets or {}) do
            set_weight = set_weight + (tonumber(set.weight) or 0)
            for _, key in ipairs(set.keys or {}) do
                check(not set_keys[key], "duplicate joker across draft sets")
                set_keys[key] = true
            end
        end
        check(set_weight == 100, "draft set weights must total 100")
        for _, key in ipairs({ "j_caino", "j_triboulet", "j_yorick", "j_chicot", "j_perkeo" }) do
            check(not set_keys[key], "legendary Joker must not be in the forced draft pool")
        end
        check(BD.logic.is_legendary({ set = "Joker", rarity = 4 }), "legendary detection failed")
        check(not BD.logic.is_legendary({ set = "Joker", rarity = 3 }), "rare Joker marked legendary")

        local first = { "a", "b", "c", "d", "e", "f" }
        local second = { "a", "b", "c", "d", "e", "f" }
        BD.rng.shuffle(first, "test")
        BD.rng.shuffle(second, "test")
        for index = 1, #first do check(first[index] == second[index], "rng is not deterministic") end

        local data = {
            pairs = {
                { "j_joker", "j_sly", side = "host", round = 1 },
                { "j_marble", "j_half", side = "guest", round = 1 },
                { "j_banner", "j_abstract", side = "host", round = 2 },
                { "j_even", "j_odd", side = "guest", round = 2 },
            },
            picks = {
                { pair = 1, player = "host", choice = 1, key = "j_joker" },
                { pair = 2, player = "guest", choice = 1, key = "j_marble" },
                { pair = 3, player = "host", choice = 2, key = "j_abstract" },
                { pair = 4, player = "guest", choice = 2, key = "j_odd" },
            },
        }
        BD.logic.finalize(data)
        check(#data.host_keys == 4 and #data.guest_keys == 4, "pool finalize failed")
        check(data.host_keys[1] == "j_joker" and data.host_keys[4] == "j_even", "host picks incorrect")
        check(data.guest_keys[1] == "j_sly" and data.guest_keys[4] == "j_odd", "guest picks incorrect")
        check(data.host_keys[2] == "j_half" and data.guest_keys[3] == "j_banner", "unpicked Jokers not passed")

        local reverse = {
            reverse_draft = true,
            host_keys = { "a", "b" },
            guest_keys = { "c", "d" },
        }
        local eligible = { "a", "b", "c", "d", "e" }
        local host_pool = BD.logic.pool_for(reverse, "host", eligible)
        local guest_pool = BD.logic.pool_for(reverse, "guest", eligible)
        check(#host_pool == 3 and host_pool[1] == "a" and host_pool[3] == "e", "reverse host pool failed")
        check(#guest_pool == 3 and guest_pool[1] == "c" and guest_pool[3] == "e", "reverse guest pool failed")

        BD.state.role = "host"
        local clock = (love and love.timer and love.timer.getTime()) or os.time()
        BD.state.data = {
            draft_id = "timer-test",
            phase = "summary",
            pick_seconds = 20,
            done = { host = false, guest = false },
            summary_deadline = clock + 100,
        }
        check(BD.state.remaining() > 90, "summary continue timer is running")
        BD.state.role = previous_role

        BD.draft_sets = {
            { id = "alpha", weight = 1, keys = { "a", "b", "c", "d", "e", "f", "g", "h" } },
            { id = "beta", weight = 1, keys = { "i", "j", "k", "l", "m", "n", "o", "p" } },
        }
        local shared = {}
        for _, key in ipairs({ "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p" }) do
            shared[#shared + 1] = key
        end
        local built = BD.logic.build_category_pairs(shared, 2, "test", "host")
        check(built and #built == 4, "category draft failed")
        check(built[1].category == built[2].category, "round categories differ")
        check(built[3].category == built[4].category, "round categories differ")
        check(built[1].side ~= built[2].side and built[3].side ~= built[4].side, "round sides incorrect")
        local seen = {}
        for _, pair in ipairs(built) do
            for index = 1, 2 do
                check(not seen[pair[index]], "category draft repeated a joker")
                seen[pair[index]] = true
            end
        end

        BD.state.data = {
            draft_id = "snapshot-test",
            pair_count = 4,
            round_count = 2,
            pair_index = 1,
            turn = "guest",
            phase = "choosing",
            first = "host",
            pairs = { { "a", "b", side = "guest", round = 1, category = "alpha" } },
            host_keys = {},
            guest_keys = {},
            done = { host = false, guest = false },
            seq = 1,
            pick_seconds = 20,
            names = { host = "host", guest = "guest" },
            blind_draft = false,
            reverse_draft = false,
        }
        BD.state.remaining = function() return 1 end
        local snap = BD.state.snapshot()
        check(snap and snap.current_pair and #snap.current_pair == 2, "snapshot pair failed")
        check(snap.current_pair[1] == "a" and snap.current_pair[2] == "b", "snapshot pair keys incorrect")
        check(snap.current_category == nil, "snapshot leaked the draft set")
        for key in pairs(snap.current_pair) do check(type(key) == "number", "snapshot pair must be an array") end

        BD.state.data.turn = "host"
        local open_snap = BD.state.snapshot()
        check(open_snap and open_snap.current_pair, "open draft should reveal opponent pair")

        BD.state.data.blind_draft = true
        local blind_snap = BD.state.snapshot()
        check(blind_snap and blind_snap.current_pair == nil, "blind draft leaked opponent pair")

        BD.state.data.turn = "guest"
        local own_snap = BD.state.snapshot()
        check(own_snap and own_snap.current_pair, "blind draft should send own pair")
    end)
    BD.draft_sets = previous_sets
    BD.state.data, BD.state.remaining = old_data, old_remaining
    BD.state.role = previous_role
    if not ok then BD.warn("self-test failed: " .. tostring(err)) end
end