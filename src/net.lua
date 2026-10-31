BD.net = {}

function BD.net.enabled()
    return MP
        and MP.LOBBY
        and MP.LOBBY.code
        and MP.ACTIONS
        and type(MP.ACTIONS.modded) == "function"
end

function BD.net.send(action, params)
    if not BD.net.enabled() then return false end
    MP.ACTIONS.modded(BD.MOD_ID, action, params or {})
    return true
end

function BD.net.send_hello(params)
    return BD.net.send("draft_hello", params)
end

function BD.net.send_state(snapshot)
    if not snapshot then return false end
    return BD.net.send("draft_state", { state = snapshot })
end

function BD.net.send_pick(seq, choice)
    local data = BD.state.data
    return BD.net.send("draft_pick", {
        draft_id = data and data.draft_id or nil,
        seq = seq,
        choice = choice,
    })
end

function BD.net.send_done()
    local data = BD.state.data
    return BD.net.send("draft_done", { draft_id = data and data.draft_id or nil })
end

function BD.net.send_finish()
    local data = BD.state.data
    return BD.net.send("draft_finish", { draft_id = data and data.draft_id or nil })
end

function BD.net.send_abort(message)
    local data = BD.state.data
    return BD.net.send("draft_abort", {
        draft_id = data and data.draft_id or nil,
        message = message,
    })
end

function BD.net.dispatch(action, payload)
    local ok, err = pcall(function()
        if action == "draft_hello" then
            BD.state.receive_hello(payload)
        elseif action == "draft_state" then
            BD.state.receive_state(payload)
        elseif action == "draft_pick" then
            BD.state.receive_pick(payload)
        elseif action == "draft_done" then
            BD.state.receive_done(payload)
        elseif action == "draft_finish" then
            BD.state.receive_finish(payload)
        elseif action == "draft_abort" then
            BD.state.receive_abort(payload)
        end
    end)
    if not ok then BD.warn("network handler failed for " .. tostring(action) .. ": " .. tostring(err)) end
end

function BD.net.install()
    if BD.net.installed then return end
    BD.net.installed = true
    if not MP or not MP.register_mod_action then
        BD.warn("Multiplayer mod action API is unavailable")
        return
    end
    local actions = {
        "draft_hello",
        "draft_state",
        "draft_pick",
        "draft_done",
        "draft_finish",
        "draft_abort",
    }
    for _, action in ipairs(actions) do
        MP.register_mod_action(action, function(payload)
            BD.net.dispatch(action, payload)
        end, BD.MOD_ID)
    end
end
