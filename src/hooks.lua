BD.hooks = {}

function BD.hooks.install()
    if BD.hooks.installed then return end
    BD.hooks.installed = true

    local start_ref = Game.start_run
    function Game:start_run(args)
        local token = BD.state.prepare_start()
        start_ref(self, args)

        if args and args.savetext then
            BD.logic.restore_bans()
            return
        end

        if not BD.in_mp() or not BD.is_draft_ruleset() then return end

        G.GAME.bd_base_banned = nil
        G.GAME.bd_draft_pool = nil
        BD.logic.capture_base_bans()

        G.E_MANAGER:add_event(Event({
            trigger = "after",
            timer = "REAL",
            delay = 1.2,
            blocking = false,
            blockable = false,
            func = function()
                if BD.state.start_token ~= token then return true end
                if not BD.in_mp() or not BD.is_draft_ruleset() then return true end
                BD.state.begin()
                return true
            end,
        }))
    end

    local update_ref = Game.update
    function Game:update(dt)
        update_ref(self, dt)
        if BD.state and BD.state.tick then BD.state.tick(dt) end
    end

    local delete_ref = Game.delete_run
    function Game:delete_run(...)
        if BD.state.active then BD.state.cancel() end
        return delete_ref(self, ...)
    end

    local pool_ref = get_current_pool
    function get_current_pool(_type, _rarity, _legendary, _append)
        local pool, key = pool_ref(_type, _rarity, _legendary, _append)
        local legendary = _legendary ~= nil and _legendary ~= false or tonumber(_rarity) == 4
        if _type == "Joker" and BD.logic.has_filter() and not legendary then
            return BD.logic.filter_pool(pool), key
        end
        return pool, key
    end

    BD.log("Hooks installed")
end
