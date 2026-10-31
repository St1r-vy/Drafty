BD.ui = {}
BD.ui.card_areas = {}
BD.ui.status_ref = { text = "" }
BD.ui.visible = false

local function wrap(text, width)
    if MP.UTILS and MP.UTILS.wrapText then return MP.UTILS.wrapText(text, width or 74) end
    return text
end

local function joker_name(key)
    local descriptions = G.localization and G.localization.descriptions and G.localization.descriptions.Joker
    local entry = descriptions and descriptions[key]
    local name = entry and entry.name
    if type(name) == "table" then return table.concat(name, " ") end
    return name or key
end

local function text_row(text, scale, colour)
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.03 },
        nodes = {
            {
                n = G.UIT.T,
                config = {
                    text = text,
                    scale = scale or 0.38,
                    colour = colour or G.C.UI.TEXT_LIGHT,
                    shadow = true,
                },
            },
        },
    }
end

local function status_row(text, scale, colour)
    BD.ui.status_ref.text = text
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.03 },
        nodes = {
            {
                n = G.UIT.T,
                config = {
                    ref_table = BD.ui.status_ref,
                    ref_value = "text",
                    scale = scale or 0.5,
                    colour = colour or G.C.UI.TEXT_LIGHT,
                    shadow = true,
                },
            },
        },
    }
end

local function header(text)
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.08 },
        nodes = {
            {
                n = G.UIT.T,
                config = {
                    text = text,
                    scale = 0.72,
                    colour = G.C.GOLD,
                    shadow = true,
                },
            },
        },
    }
end

local function timer_row()
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.04 },
        nodes = {
            {
                n = G.UIT.T,
                config = {
                    ref_table = BD.state.timer_ref,
                    ref_value = "text",
                    scale = 0.5,
                    colour = G.C.RED,
                    shadow = true,
                },
            },
        },
    }
end

local function button(id, label, enabled, colour, minw, minh)
    return {
        n = G.UIT.C,
        config = {
            id = id,
            button = enabled and id or nil,
            align = "cm",
            padding = 0.05,
            r = 0.1,
            minw = minw or 2.4,
            minh = minh or 0.62,
            colour = colour or (enabled and G.C.BLUE or G.C.GREY),
            hover = enabled,
            shadow = true,
        },
        nodes = {
            {
                n = G.UIT.T,
                config = {
                    text = label,
                    scale = 0.4,
                    colour = G.C.UI.TEXT_LIGHT,
                },
            },
        },
    }
end

local function card_row(keys, size)
    local width = math.max(G.CARD_W * size, #keys * G.CARD_W * size + 0.15)
    local area = CardArea(0, 0, width, G.CARD_H * size, {
        card_limit = #keys,
        type = "title_2",
        view_deck = true,
        highlight_limit = 0,
        card_w = G.CARD_W * size,
    })
    for _, key in ipairs(keys) do
        local center = G.P_CENTERS[key]
        if center then
            local card = Card(0, 0, G.CARD_W * size, G.CARD_H * size, nil, center, {
                bypass_discovery_center = true,
                bypass_discovery_ui = true,
            })
            area:emplace(card)
        end
    end
    BD.ui.card_areas[#BD.ui.card_areas + 1] = area
    return {
        n = G.UIT.R,
        config = { align = "cm", padding = 0.04, minw = width },
        nodes = {
            { n = G.UIT.O, config = { object = area } },
        },
    }
end

local function root(nodes, width, height)
    return {
        n = G.UIT.ROOT,
        config = {
            align = "cm",
            colour = G.C.BLACK,
            r = 0.12,
            minw = width or 11,
            minh = height or 7,
            padding = 0.18,
            emboss = 0.05,
        },
        nodes = nodes,
    }
end

local function waiting_definition()
    local other = BD.username(BD.other(BD.state.role))
    local message = BD.state.role == "guest"
        and BD.format("k_draft_waiting_host", { name = other })
        or BD.format("k_draft_waiting_opponent", { name = other })
    return root({
        header(BD.loc("k_draft_title")),
        text_row(wrap(message), 0.42),
        timer_row(),
        text_row(BD.loc("k_draft_waiting_hint"), 0.3, G.C.UI.TEXT_INACTIVE),
    }, 10, 5)
end

local function choosing_definition()
    local data = BD.state.data
    local pair = data.current_pair or (data.pairs and data.pairs[data.pair_index])
    local local_turn = data.turn == BD.state.role
    local blind = data.blind_draft == true
    local other = BD.username(BD.other(BD.state.role))
    local round = data.current_round or (pair and pair.round) or math.ceil((data.pair_index or 1) / 2)
    local total = data.round_count or math.max(1, math.ceil((data.pair_count or 0) / 2))
    local progress = BD.format("k_draft_pair_progress", { current = round, total = total })

    local function choice_column(index, enabled)
        local key = pair and pair[index]
        local name = text_row(joker_name(key), 0.34, G.C.GOLD)
        name.config.minw = 2.8
        name.config.maxw = 2.8
        local nodes = {
            card_row({ key }, 0.8),
            name,
        }
        if enabled ~= nil then
            nodes[#nodes + 1] = {
                n = G.UIT.R,
                config = { align = "cm", padding = 0.02 },
                nodes = {
                    button("bd_pick_" .. tostring(index), BD.loc("k_draft_pick"), enabled, nil, 2.8, 0.5),
                },
            }
        end
        return {
            n = G.UIT.C,
            config = { align = "tm", padding = 0.08, minw = 2.8 },
            nodes = nodes,
        }
    end

    local function pair_row(enabled)
        return {
            n = G.UIT.R,
            config = { align = "cm", padding = 0.08 },
            nodes = {
                choice_column(1, enabled),
                { n = G.UIT.C, config = { align = "cm", padding = 0.08 }, nodes = { text_row(BD.loc("k_draft_or"), 0.32, G.C.UI.TEXT_INACTIVE) } },
                choice_column(2, enabled),
            },
        }
    end

    local function base_nodes(status, colour)
        return {
            header(BD.loc("k_draft_title")),
            text_row(progress, 0.34, G.C.UI.TEXT_INACTIVE),
            status_row(status, 0.5, colour),
            timer_row(),
        }
    end

    if not local_turn then
        local status = BD.format(
            blind and "k_draft_blind_opponent_turn" or "k_draft_opponent_turn",
            { name = other }
        )
        local nodes = base_nodes(status, G.C.ORANGE)
        if blind or not pair then
            local note = blind and "k_draft_blind_choosing_note" or "k_draft_opponent_turn_note"
            nodes[#nodes + 1] = text_row(BD.loc(note), 0.3, G.C.UI.TEXT_INACTIVE)
            return root(nodes, 10, 5)
        end
        nodes[#nodes + 1] = text_row(BD.format("k_draft_opponent_options", { name = other }), 0.36, G.C.GOLD)
        nodes[#nodes + 1] = pair_row(nil)
        nodes[#nodes + 1] = text_row(BD.loc("k_draft_open_opponent_note"), 0.3, G.C.UI.TEXT_INACTIVE)
        return root(nodes, 11, 7)
    end

    if not pair then
        local nodes = base_nodes(BD.loc("k_draft_waiting_short"), G.C.ORANGE)
        nodes[#nodes + 1] = text_row(BD.loc("k_draft_opponent_turn_note"), 0.3, G.C.UI.TEXT_INACTIVE)
        return root(nodes, 10, 5)
    end

    local enabled = BD.state.can_pick()
    local status = BD.state.pending and BD.loc("k_draft_sent") or BD.loc("k_draft_your_turn")
    local nodes = base_nodes(status, G.C.GREEN)
    nodes[#nodes + 1] = pair_row(enabled)
    nodes[#nodes + 1] = text_row(BD.loc("k_draft_assign_hint"), 0.3, G.C.UI.TEXT_INACTIVE)

    return root(nodes, 11, 7)
end

local SUMMARY_SIZE = 0.65
local SUMMARY_ROWS = 2
local SUMMARY_MAX_WIDTH = 6.0

local function summary_per_row()
    return math.max(1, math.floor((SUMMARY_MAX_WIDTH - 0.15) / (G.CARD_W * SUMMARY_SIZE)))
end

local function summary_column(title, keys, page, per_row, page_size, size)
    local nodes = { text_row(title, 0.4, G.C.GOLD) }
    local first = (page - 1) * page_size + 1
    local last = math.min(#keys, first + page_size - 1)
    for start = first, last, per_row do
        local row = {}
        for index = start, math.min(last, start + per_row - 1) do
            row[#row + 1] = keys[index]
        end
        nodes[#nodes + 1] = card_row(row, size)
    end
    nodes[#nodes + 1] = text_row(BD.format("k_draft_pool_count", { count = #keys }), 0.3, G.C.UI.TEXT_INACTIVE)
    return {
        n = G.UIT.C,
        config = { align = "tm", padding = 0.08 },
        nodes = nodes,
    }
end

local function summary_definition()
    local data = BD.state.data
    local local_name = BD.username(BD.state.role)
    local other_name = BD.username(BD.other(BD.state.role))
    local done = BD.state.local_done()
    local waiting = done and BD.loc("k_draft_waiting_continue") or BD.loc("k_draft_continue")
    local blind = data.blind_draft == true
    local reverse = data.reverse_draft == true
    local hint
    if blind and reverse then
        hint = BD.loc("k_draft_blind_reverse_summary")
    elseif blind then
        hint = BD.loc("k_draft_blind_summary")
    elseif reverse then
        hint = BD.loc("k_draft_reverse_summary")
    else
        hint = BD.loc("k_draft_summary_hint")
    end
    local local_keys = BD.state.local_keys(data)
    local opponent_keys = blind and {} or BD.state.opponent_keys(data)
    local size = SUMMARY_SIZE
    local per_row = summary_per_row()
    local page_size = per_row * SUMMARY_ROWS
    local pages = math.max(1, math.ceil(math.max(#local_keys, #opponent_keys) / page_size))
    if BD.ui.summary_draft ~= data.draft_id then
        BD.ui.summary_draft = data.draft_id
        BD.ui.summary_page = 1
    end
    local page = math.max(1, math.min(BD.ui.summary_page or 1, pages))
    BD.ui.summary_page = page

    local pool_nodes = {
        summary_column(BD.format("k_draft_your_pool", { name = local_name }), local_keys, page, per_row, page_size, size),
    }
    if not blind then
        pool_nodes[#pool_nodes + 1] = { n = G.UIT.C, config = { minw = 0.2, minh = 0.2 } }
        pool_nodes[#pool_nodes + 1] = summary_column(
            BD.format("k_draft_their_pool", { name = other_name }),
            opponent_keys,
            page,
            per_row,
            page_size,
            size
        )
    end

    local controls = {}
    if pages > 1 then
        controls[#controls + 1] = button("bd_summary_prev", BD.loc("k_draft_prev"), page > 1, G.C.BLUE, 1.2, 0.55)
        controls[#controls + 1] = {
            n = G.UIT.C,
            config = { align = "cm", padding = 0.05 },
            nodes = {
                {
                    n = G.UIT.T,
                    config = {
                        text = BD.format("k_draft_page", { page = page, total = pages }),
                        scale = 0.34,
                        colour = G.C.UI.TEXT_INACTIVE,
                        shadow = true,
                    },
                },
            },
        }
        controls[#controls + 1] = button("bd_summary_next", BD.loc("k_draft_next"), page < pages, G.C.BLUE, 1.2, 0.55)
    end
    controls[#controls + 1] = button("bd_continue", waiting, not done, done and G.C.GREY or G.C.BLUE)

    return root({
        header(BD.loc("k_draft_complete")),
        text_row(wrap(hint, 74), 0.34),
        timer_row(),
        {
            n = G.UIT.R,
            config = { align = "cm", padding = 0.08 },
            nodes = pool_nodes,
        },
        {
            n = G.UIT.R,
            config = { align = "cm", padding = 0.08 },
            nodes = controls,
        },
    }, 13, 7)
end

local function error_definition()
    return root({
        header(BD.loc("k_draft_error_title")),
        text_row(wrap(BD.state.error_message or BD.loc("k_draft_err_generic"), 70), 0.42, G.C.RED),
        {
            n = G.UIT.R,
            config = { align = "cm", padding = 0.12 },
            nodes = {
                button("bd_close_error", BD.loc("k_draft_close"), true, G.C.RED),
            },
        },
    }, 10, 5)
end

function BD.ui.build()
    if BD.state.error_message then return error_definition() end
    if not BD.state.data then return waiting_definition() end
    if BD.state.data.phase == "summary" then return summary_definition() end
    return choosing_definition()
end

function BD.ui.cleanup(areas)
    for _, area in ipairs(areas or {}) do
        if area and area.remove then pcall(area.remove, area) end
    end
end

function BD.ui.set_pending()
    if not BD.state.active or not BD.state.data or BD.state.data.phase ~= "choosing" then return end
    BD.ui.status_ref.text = BD.loc("k_draft_sent")
end

function BD.ui.refresh()
    if not BD.state.active then return end
    BD.state.update_timer_text()
    local old_areas = BD.ui.card_areas or {}
    BD.ui.card_areas = {}
    local definition = BD.ui.build()
    G.SETTINGS.paused = true
    G.FUNCS.overlay_menu({
        definition = definition,
        config = { no_esc = true },
    })
    BD.ui.visible = true
    BD.ui.cleanup(old_areas)
end

function BD.ui.hide()
    if BD.ui.visible then
        pcall(G.FUNCS.exit_overlay_menu)
        BD.ui.visible = false
        if not G.OVERLAY_MENU and G.SETTINGS then G.SETTINGS.paused = false end
    end
    BD.ui.cleanup(BD.ui.card_areas)
    BD.ui.card_areas = {}
end

G.FUNCS.bd_pick_1 = function()
    BD.state.pick(1)
end

G.FUNCS.bd_pick_2 = function()
    BD.state.pick(2)
end

G.FUNCS.bd_summary_prev = function()
    if not BD.state.data or BD.state.data.phase ~= "summary" then return end
    local page = BD.ui.summary_page or 1
    if page <= 1 then return end
    BD.ui.summary_page = page - 1
    BD.ui.refresh()
end

G.FUNCS.bd_summary_next = function()
    if not BD.state.data or BD.state.data.phase ~= "summary" then return end
    BD.ui.summary_page = (BD.ui.summary_page or 1) + 1
    BD.ui.refresh()
end

G.FUNCS.bd_continue = function()
    BD.state.finish_click()
end

G.FUNCS.bd_close_error = function()
    BD.state.close_error()
end