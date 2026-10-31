BD.lobby_ui = {}

function BD.lobby_ui.change_pairs(args)
    local value = tonumber(args and args.to_val) or BD.config.get_default_cards()
    MP.LOBBY.config.draft_pairs = value
    MP.ACTIONS.lobby_options()
end

function BD.lobby_ui.change_timer(args)
    local value = tonumber(tostring(args and args.to_val or ""):match("%d+")) or BD.config.default_seconds
    MP.LOBBY.config.draft_pick_seconds = value
    MP.ACTIONS.lobby_options()
end

function BD.lobby_ui.install_ruleset_button()
    if not MP or not MP.Rulesets or not MP.Rulesets["ruleset_mp_draft"] then return end
    local ref = G.UIDEF.ruleset_selection_options
    if type(ref) ~= "function" or BD.lobby_ui.ruleset_button_installed then return end
    BD.lobby_ui.ruleset_button_installed = true

    G.UIDEF.ruleset_selection_options = function(mode, buttons)
        if (mode ~= nil and mode ~= "mp") or type(buttons) ~= "table" then
            return ref(mode, buttons)
        end

        local target_index = nil
        for index, group in ipairs(buttons) do
            if type(group) == "table" and type(group.buttons) == "table" then
                for _, button in ipairs(group.buttons) do
                    if button.button_id == "standard_ranked_ruleset_button" then
                        target_index = index
                        break
                    end
                end
            end
            if target_index then break end
        end
        if not target_index then
            for index, group in ipairs(buttons) do
                if type(group) == "table" and group.name == "k_matchmaking" then
                    target_index = index
                    break
                end
            end
        end
        if not target_index then return ref(mode, buttons) end

        local copy = {}
        for index, group in ipairs(buttons) do copy[index] = group end
        local target = {}
        for key, value in pairs(buttons[target_index]) do target[key] = value end
        target.buttons = {}
        for index, button in ipairs(buttons[target_index].buttons) do target.buttons[index] = button end
        copy[target_index] = target

        local present = false
        local insert_at = #target.buttons + 1
        for index, button in ipairs(target.buttons) do
            if button.button_id == "draft_ruleset_button" then present = true end
            if button.button_id == "standard_ranked_ruleset_button" then insert_at = index + 1 end
        end
        if not present then
            table.insert(target.buttons, insert_at, {
                button_id = "draft_ruleset_button",
                button_localize_key = "k_draft",
            })
        end

        return ref(mode, copy)
    end
end

function BD.lobby_ui.create_draft_tab()
    local pair_options = BD.config.card_options
    local timer_options = {}
    local timer_labels = {}
    for index, value in ipairs(BD.config.second_options) do
        timer_options[index] = value
        timer_labels[index] = tostring(value) .. "s"
    end

    return {
        n = G.UIT.ROOT,
        config = {
            emboss = 0.05,
            minh = 4.5,
            r = 0.1,
            minw = 10,
            align = "tm",
            padding = 0.2,
            colour = G.C.BLACK,
        },
        nodes = {
            create_lobby_option_cycle(
                "draft_pairs_option",
                "k_draft_opt_pairs",
                0.85,
                pair_options,
                BD.config.option_index(pair_options, BD.config.get_pairs()),
                "change_draft_pairs"
            ),
            create_lobby_option_toggle("draft_blind_toggle", "k_draft_opt_blind", "draft_blind"),
            create_lobby_option_toggle("draft_reverse_toggle", "k_draft_opt_reverse", "draft_reverse"),
            create_lobby_option_cycle(
                "draft_timer_option",
                "k_draft_opt_timer",
                0.85,
                timer_labels,
                BD.config.option_index(timer_options, BD.config.get_seconds()),
                "change_draft_timer"
            ),
            {
                n = G.UIT.R,
                config = { padding = 0.08, align = "cm" },
                nodes = {
                    { n = G.UIT.T, config = {
                        text = BD.loc("k_draft_lobby_blind_note"),
                        scale = 0.34,
                        colour = G.C.UI.TEXT_INACTIVE,
                    }},
                },
            },
            {
                n = G.UIT.R,
                config = { padding = 0.08, align = "cm" },
                nodes = {
                    { n = G.UIT.T, config = {
                        text = BD.loc("k_draft_lobby_reverse_note"),
                        scale = 0.34,
                        colour = G.C.UI.TEXT_INACTIVE,
                    }},
                },
            },
        },
    }
end

function BD.lobby_ui.install_draft_tab()
    if BD.lobby_ui.draft_tab_installed then return end
    local options_ref = G.UIDEF.create_UIBox_lobby_options
    if type(options_ref) ~= "function" then return end
    BD.lobby_ui.draft_tab_installed = true

    G.UIDEF.create_UIBox_lobby_options = function(...)
        BD.lobby_ui.insert_draft_tab = true
        local ok, result = pcall(options_ref, ...)
        BD.lobby_ui.insert_draft_tab = false
        if not ok then error(result) end
        return result
    end

    local tabs_ref = create_tabs
    if type(tabs_ref) ~= "function" then
        BD.warn("could not add the Draft lobby tab: create_tabs is unavailable")
        return
    end

    create_tabs = function(args, ...)
        if BD.lobby_ui.insert_draft_tab then
            BD.lobby_ui.insert_draft_tab = false
            if type(args) == "table" and type(args.tabs) == "table" and BD.is_draft_ruleset() then
                local present = false
                for _, tab in ipairs(args.tabs) do
                    if type(tab) == "table" and tab.label == BD.loc("k_draft") then
                        present = true
                        break
                    end
                end
                if not present then
                    table.insert(args.tabs, {
                        label = BD.loc("k_draft"),
                        tab_definition_function = BD.lobby_ui.create_draft_tab,
                    })
                end
            end
        end
        return tabs_ref(args, ...)
    end
end

function BD.lobby_ui.install()
    G.FUNCS.change_draft_pairs = BD.lobby_ui.change_pairs
    G.FUNCS.change_draft_timer = BD.lobby_ui.change_timer
    BD.lobby_ui.install_ruleset_button()
    BD.lobby_ui.install_draft_tab()
    BD.config.install()
end