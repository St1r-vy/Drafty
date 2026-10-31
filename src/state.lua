BD.state = {
    active = false,
    role = nil,
    data = nil,
    eligible = nil,
    pending = false,
    pending_hello = nil,
    hello_sent = false,
    start_token = 0,
    last_state_seq = 0,
    timer_ref = { text = "" },
}

local function now()
    if love and love.timer then return love.timer.getTime() end
    return os.time()
end

function BD.state.cancel(message)
    if not BD.state.active then return end
    if BD.state.data then BD.net.send_abort(message or BD.loc("k_draft_err_aborted")) end
    BD.state.complete()
end

function BD.state.prepare_start()
    if BD.state.active then BD.state.cancel() end
    BD.state.active = false
    BD.state.role = nil
    BD.state.data = nil
    BD.state.eligible = nil
    BD.state.pending = false
    BD.state.pending_hello = nil
    BD.state.hello_sent = false
    BD.state.last_state_seq = 0
    BD.state.error_message = nil
    BD.state.local_pool = nil
    BD.state.begin_time = nil
    BD.state.start_token = (BD.state.start_token or 0) + 1
    BD.state.timer_ref.text = ""
    return BD.state.start_token
end

function BD.state.local_keys(data)
    data = data or BD.state.data
    if not data or not BD.state.role then return {} end
    return data[BD.state.role .. "_keys"] or {}
end

function BD.state.opponent_keys(data)
    data = data or BD.state.data
    if not data or not BD.state.role then return {} end
    return data[BD.other(BD.state.role) .. "_keys"] or {}
end

function BD.state.is_local_turn()
    local data = BD.state.data
    return data ~= nil and data.phase == "choosing" and data.turn == BD.state.role
end

function BD.state.can_pick()
    return BD.state.active
        and not BD.state.error_message
        and not BD.state.pending
        and BD.state.is_local_turn()
end

function BD.state.remaining()
    local data = BD.state.data
    if not data then return 0 end
    if data.phase == "choosing" then
        if BD.state.role == "host" then
            if not data.deadline then return data.pick_seconds or 0 end
            return math.max(0, data.deadline - now() - 1)
        end
        if not data.received_at then return data.remaining or 0 end
        return math.max(0, (data.remaining or 0) - (now() - data.received_at))
    end
    if data.phase == "summary" then
        if BD.state.role == "host" then
            if not data.summary_deadline then return data.pick_seconds or 0 end
            return math.max(0, data.summary_deadline - now() - 1)
        end
        if not data.received_at then return data.remaining or 0 end
        return math.max(0, (data.remaining or 0) - (now() - data.received_at))
    end
    return 0
end

function BD.state.update_timer_text()
    local text = ""
    if BD.state.active and not BD.state.error_message then
        if BD.state.data then
            local phase = BD.state.data.phase
            local summary_pending = phase == "summary"
                and not (BD.state.data.done and BD.state.data.done.host and BD.state.data.done.guest)
            if phase == "choosing" or summary_pending then
                text = string.format("%ds", math.max(0, math.ceil(BD.state.remaining())))
            end
        elseif BD.state.role == "guest" then
            text = BD.loc("k_draft_connecting")
        else
            text = BD.loc("k_draft_waiting_short")
        end
    end
    BD.state.timer_ref.text = text
end

function BD.state.snapshot()
    local data = BD.state.data
    if not data then return nil end
    local pair = data.pairs and data.pairs[data.pair_index]
    local snap = {
        draft_id = data.draft_id,
        pair_count = data.pair_count,
        round_count = data.round_count,
        pair_index = data.pair_index,
        turn = data.turn,
        phase = data.phase,
        first = data.first,
        current_round = pair and pair.round,
        host_keys = data.host_keys or {},
        guest_keys = data.guest_keys or {},
        done = data.done or { host = false, guest = false },
        seq = data.seq or 0,
        remaining = math.max(0, BD.state.remaining()),
        pick_seconds = data.pick_seconds,
        names = data.names or {},
        blind_draft = data.blind_draft == true,
        reverse_draft = data.reverse_draft == true,
    }
    if data.phase == "choosing" and pair and (not data.blind_draft or data.turn == "guest") then
        snap.current_pair = { pair[1], pair[2] }
    end
    if snap.blind_draft and not snap.reverse_draft then
        snap.host_keys = nil
    end
    return snap
end

function BD.state.set_deadline()
    local data = BD.state.data
    if not data then return end
    data.deadline = now() + (data.pick_seconds or 20) + 1
end

function BD.state.set_summary_deadline()
    local data = BD.state.data
    if not data then return end
    data.summary_deadline = now() + (data.pick_seconds or 20) + 1
end

function BD.state.apply_local_pool(data)
    if not data or not BD.state.role then return end
    local keys = BD.logic.pool_for(data, BD.state.role, BD.state.eligible)
    if #keys > 0 then
        BD.state.local_pool = keys
        BD.logic.set_local_pool(keys)
    end
end

function BD.state.begin()
    if not BD.in_mp() then return end
    BD.state.active = true
    BD.state.role = MP.LOBBY.is_host and "host" or "guest"
    BD.state.seed = G.GAME and G.GAME.pseudorandom and G.GAME.pseudorandom.seed or "seed"
    BD.state.begin_time = now()
    BD.state.data = nil
    BD.state.pending = false
    BD.state.error_message = nil
    BD.state.local_pool = nil
    BD.state.eligible = BD.logic.get_eligible()
    BD.state.last_state_seq = 0
    BD.state.hello_sent = false

    if #BD.state.eligible < 4 * BD.config.get_pairs() then
        BD.state.fail(BD.loc("k_draft_err_not_enough"))
        return
    end

    BD.state.update_timer_text()
    if BD.ui and BD.ui.refresh then BD.ui.refresh() end

    if BD.state.role == "guest" then
        BD.state.send_hello()
    elseif BD.state.pending_hello then
        local hello = BD.state.pending_hello
        BD.state.pending_hello = nil
        BD.state.host_hello(hello)
    end
end

function BD.state.send_hello()
    if BD.state.role ~= "guest" or not BD.state.active then return end
    BD.state.hello_sent = true
    BD.state.last_hello_at = now()
    BD.net.send_hello({
        code = MP.LOBBY.code,
        seed = BD.state.seed,
        name = BD.username("guest"),
        keys = BD.state.eligible or {},
    })
end

function BD.state.host_hello(p)
    if BD.state.role ~= "host" or not BD.state.active or BD.state.data then return end
    if BD.state.error_message then return end
    if p.code and p.code ~= MP.LOBBY.code then return end
    if type(p.keys) ~= "table" then return end

    local shared = BD.logic.intersect(BD.state.eligible or {}, p.keys)
    local count = BD.config.get_pairs()
    if #shared < 4 * count then
        BD.state.fail(BD.loc("k_draft_err_shared"))
        return
    end

    local draft_id = BD.rng.id(BD.state.seed, p.name or "guest", now())
    local first_side = BD.rng.int(draft_id .. ":first", 2) == 1 and "host" or "guest"
    local pairs = BD.logic.build_category_pairs(shared, count, draft_id, first_side)
    if not pairs then
        BD.state.fail(BD.loc("k_draft_err_shared"))
        return
    end

    BD.state.data = {
        draft_id = draft_id,
        pair_count = 2 * count,
        round_count = count,
        pairs = pairs,
        picks = {},
        pair_index = 1,
        turn = pairs[1].side,
        phase = "choosing",
        first = pairs[1].side,
        host_keys = {},
        guest_keys = {},
        done = { host = false, guest = false },
        seq = 1,
        pick_seconds = BD.config.get_seconds(),
        blind_draft = BD.config.get_blind(),
        reverse_draft = BD.config.get_reverse(),
        names = {
            host = BD.username("host"),
            guest = BD.username("guest"),
        },
    }
    BD.state.last_state_seq = 1
    BD.state.set_deadline()
    BD.state.update_timer_text()
    if BD.ui and BD.ui.refresh then BD.ui.refresh() end
    BD.net.send_state(BD.state.snapshot())
end

function BD.state.fail(message, notify)
    if not BD.state.active then return end
    if BD.state.error_message then return end
    BD.state.error_message = message or BD.loc("k_draft_err_generic")
    BD.state.pending = false
    if notify ~= false and (BD.state.role == "host" or BD.state.data) then
        BD.net.send_abort(BD.state.error_message)
    end
    BD.state.update_timer_text()
    if BD.ui and BD.ui.refresh then BD.ui.refresh() end
end

function BD.state.close_error()
    BD.state.error_message = nil
    BD.state.active = false
    BD.state.data = nil
    BD.state.eligible = nil
    BD.state.pending = false
    BD.state.local_pool = nil
    BD.state.timer_ref.text = ""
    if BD.ui and BD.ui.hide then BD.ui.hide() end
end

function BD.state.host_apply_pick(side, choice)
    local data = BD.state.data
    if BD.state.role ~= "host" or not data or data.phase ~= "choosing" then return false end
    if data.turn ~= side then return false end
    choice = tonumber(choice)
    if choice ~= 1 and choice ~= 2 then return false end
    local pair = data.pairs[data.pair_index]
    if not pair or pair.side ~= side then return false end

    data.picks[#data.picks + 1] = {
        pair = data.pair_index,
        player = side,
        choice = choice,
        key = pair[choice],
        category = pair.category,
    }
    data.pair_index = data.pair_index + 1

    if data.pair_index > data.pair_count then
        BD.logic.finalize(data)
        data.phase = "summary"
        data.done = { host = false, guest = false }
        data.deadline = nil
        BD.state.set_summary_deadline()
        BD.state.apply_local_pool(data)
    else
        data.turn = data.pairs[data.pair_index].side
        BD.state.set_deadline()
    end

    data.seq = (data.seq or 0) + 1
    BD.state.last_state_seq = data.seq
    BD.state.pending = false
    BD.state.update_timer_text()
    if BD.ui and BD.ui.refresh then BD.ui.refresh() end
    BD.net.send_state(BD.state.snapshot())
    return true
end

function BD.state.pick(choice)
    if not BD.state.can_pick() then return end
    if BD.state.role == "host" then
        BD.state.host_apply_pick("host", choice)
    else
        BD.state.pending = true
        BD.net.send_pick(BD.state.data.seq, choice)
        if BD.ui and BD.ui.set_pending then BD.ui.set_pending() end
    end
end

function BD.state.receive_hello(p)
    if p.code and MP.LOBBY.code and p.code ~= MP.LOBBY.code then return end
    if BD.state.error_message then return end
    if not BD.state.active or BD.state.role ~= "host" then
        BD.state.pending_hello = p
        return
    end
    BD.state.host_hello(p)
end

function BD.state.receive_pick(p)
    local data = BD.state.data
    if BD.state.role ~= "host" or not data or data.phase ~= "choosing" then return end
    if not p.draft_id or p.draft_id ~= data.draft_id then return end
    if tonumber(p.seq) ~= data.seq then return end
    if data.turn ~= "guest" then return end
    BD.state.host_apply_pick("guest", p.choice)
end

function BD.state.receive_state(p)
    if BD.state.role ~= "guest" or not BD.state.active then return end
    local incoming = p.state
    if type(incoming) ~= "table" or not incoming.draft_id then return end
    if BD.state.data and incoming.draft_id ~= BD.state.data.draft_id then return end
    if BD.state.data and tonumber(incoming.seq or 0) <= tonumber(BD.state.data.seq or 0) then return end

    incoming.received_at = now()
    BD.state.data = incoming
    BD.state.last_state_seq = incoming.seq or 0
    BD.state.pending = false
    if incoming.phase == "summary" then BD.state.apply_local_pool(incoming) end
    BD.state.update_timer_text()
    if BD.ui and BD.ui.refresh then BD.ui.refresh() end
end

function BD.state.local_done()
    local data = BD.state.data
    if not data or not data.done or not BD.state.role then return false end
    return data.done[BD.state.role] == true
end

function BD.state.receive_done(p)
    local data = BD.state.data
    if BD.state.role ~= "host" or not data or data.phase ~= "summary" then return end
    if not p.draft_id or p.draft_id ~= data.draft_id then return end
    data.done.guest = true
    if data.done.host then
        BD.state.complete_host()
    else
        data.seq = (data.seq or 0) + 1
        BD.state.last_state_seq = data.seq
        if BD.ui and BD.ui.refresh then BD.ui.refresh() end
        BD.net.send_state(BD.state.snapshot())
    end
end

function BD.state.finish_click()
    local data = BD.state.data
    if not data or data.phase ~= "summary" then return end
    if BD.state.role == "host" then
        if data.done.host then return end
        data.done.host = true
        if data.done.guest then
            BD.state.complete_host()
        else
            data.seq = (data.seq or 0) + 1
            BD.state.last_state_seq = data.seq
            if BD.ui and BD.ui.refresh then BD.ui.refresh() end
            BD.net.send_state(BD.state.snapshot())
        end
    else
        if data.done.guest then return end
        data.done.guest = true
        BD.net.send_done()
        if BD.ui and BD.ui.refresh then BD.ui.refresh() end
    end
end

function BD.state.complete_host()
    if BD.state.role ~= "host" then return end
    BD.net.send_finish()
    BD.state.complete()
end

function BD.state.receive_finish(p)
    if BD.state.role ~= "guest" then return end
    if p.draft_id and BD.state.data and p.draft_id ~= BD.state.data.draft_id then return end
    BD.state.complete()
end

function BD.state.receive_abort(p)
    if p.draft_id and BD.state.data and p.draft_id ~= BD.state.data.draft_id then return end
    BD.state.fail(p.message or BD.loc("k_draft_err_aborted"), false)
end

function BD.state.complete()
    BD.state.active = false
    BD.state.data = nil
    BD.state.eligible = nil
    BD.state.pending = false
    BD.state.pending_hello = nil
    BD.state.error_message = nil
    BD.state.timer_ref.text = ""
    if BD.ui and BD.ui.hide then BD.ui.hide() end
end

function BD.state.tick(dt)
    if not BD.state.active then return end
    if BD.state.error_message then return end
    if not BD.in_mp() then
        BD.state.fail(BD.loc("k_draft_err_disconnected"))
        return
    end

    local data = BD.state.data
    if not data then
        if BD.state.role == "guest" then
            if not BD.state.last_hello_at or now() - BD.state.last_hello_at >= 2 then
                BD.state.send_hello()
            end
            if BD.state.begin_time and now() - BD.state.begin_time > 40 then
                BD.state.fail(BD.loc("k_draft_err_no_host"))
                return
            end
        elseif BD.state.begin_time and now() - BD.state.begin_time > 40 then
            BD.state.fail(BD.loc("k_draft_err_no_opponent"))
            return
        end
    elseif BD.state.role == "host" and data.phase == "choosing" then
        if not data.deadline then BD.state.set_deadline() end
        if now() >= data.deadline then
            local choice = BD.rng.int(
                tostring(data.draft_id) .. ":timeout:" .. tostring(data.pair_index) .. ":" .. tostring(data.turn),
                2
            )
            BD.state.host_apply_pick(data.turn, choice)
        end
    elseif BD.state.role == "host" and data.phase == "summary" then
        if not (data.done.host and data.done.guest) then
            if not data.summary_deadline then BD.state.set_summary_deadline() end
            if now() >= data.summary_deadline then
                data.done.host = true
                data.done.guest = true
                BD.state.complete_host()
                return
            end
        end
    elseif BD.state.role == "guest" and data.phase == "choosing" then
        if now() - (data.received_at or now()) > (data.pick_seconds or 20) + 30 then
            BD.state.fail(BD.loc("k_draft_err_no_host"))
            return
        end
    elseif BD.state.role == "guest" and data.phase == "summary" then
        if data.received_at and not (data.done and data.done.guest) and BD.state.remaining() <= 0 then
            BD.state.finish_click()
        end
    end

    BD.state.update_timer_text()
end