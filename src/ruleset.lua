BD.ruleset = {}

function BD.ruleset.install()
    if BD.ruleset.installed then return end
    BD.ruleset.installed = true
    MP.Ruleset({
        key = "ruleset_mp_draft",
        prefix_config = { key = false },
        layers = { "standard", "ranked", "pvp_timer" },
        multiplayer_content = true,
        forced_lobby_options = false,
        force_lobby_options = function(self) return false end,
        forced_gamemode = "gamemode_mp_attrition",
    }):inject()
end
