BD.debug = {}

function BD.debug.dump_state()
    local data = BD.state and BD.state.data
    if not data then
        BD.log("draft state: inactive")
        return
    end
    BD.log(string.format(
        "draft state: role=%s phase=%s pair=%d/%d turn=%s seq=%d pending=%s",
        tostring(BD.state.role),
        tostring(data.phase),
        tonumber(data.pair_index) or 0,
        tonumber(data.pair_count) or 0,
        tostring(data.turn),
        tonumber(data.seq) or 0,
        tostring(BD.state.pending)
    ))
end

function BD.debug.grant_pool(keys)
    if type(keys) ~= "table" then return end
    BD.logic.set_local_pool(keys)
    BD.log("local draft pool replaced")
end
