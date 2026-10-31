BD = {}
BD.MOD_ID = "BalatroDraft"
BD.mod = SMODS.current_mod
BD.path = BD.mod and BD.mod.path or ""

function BD.load(file)
    local chunk, err = SMODS.load_file(file, BD.MOD_ID)
    if not chunk then
        error("BalatroDraft: failed to load " .. tostring(file) .. ": " .. tostring(err))
    end
    local ok, result = pcall(chunk)
    if not ok then
        error("BalatroDraft: failed to run " .. tostring(file) .. ": " .. tostring(result))
    end
    return result
end

BD.load("src/core.lua")

if not MP then
    BD.warn("Multiplayer is not loaded; BalatroDraft is inactive")
    return
end

BD.load("src/config.lua")
BD.load("src/rng.lua")
BD.draft_sets = BD.load("data/draft_sets.lua") or {}
BD.load("src/logic.lua")
BD.load("src/state.lua")
BD.load("src/net.lua")
BD.load("src/ui.lua")
BD.load("src/ruleset.lua")
BD.load("src/lobby_ui.lua")
BD.load("src/hooks.lua")
BD.load("src/debug.lua")
BD.load("src/tests.lua")

BD.config.install()
BD.net.install()
BD.ruleset.install()
BD.lobby_ui.install()
BD.hooks.install()

if BD.tests and BD.tests.run then BD.tests.run() end
