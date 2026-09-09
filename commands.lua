
local sources = require("sources")

-- =========================

local viewer_map = {}
local command_map = {}
local cooldown_map = {}
local command_queue = {}

-- ==================================================

local function cleanup()
    viewer_map = {}
    cooldown_map = {}
    command_queue = {}
end

local function table_count(t)
    local count = 0

    for _ in pairs(t) do
        count = count + 1
    end

    return count
end

local function add_cooldown(user, command, time)
    cooldown_map[user] = cooldown_map[user] or {}
    cooldown_map[user][command] = time or 0.5
end

local function on_cooldown(user, command)
    return cooldown_map[user] and cooldown_map[user][command] ~= nil
end

local function decrement_cooldown(delta)
    for _, cd in pairs(cooldown_map) do
        for command, time in pairs(cd) do
            if type(time) == "number" then
                time = time - delta
                if time <= 0 then
                    cd[command] = nil
                else
                    cd[command] = time
                end
            end
        end
    end
end

local function enqueue(user, fn)
    table.insert(command_queue, { user = user, fn = fn })
end

local function receive(user, inimsg)
    local command_data = command_map[inimsg]
    if command_data then
        if command_data.sitted and not viewer_map[user] then
            return
        end
        if not on_cooldown(user, inimsg) then
            add_cooldown(user, inimsg, command_data.t)
            enqueue(user, command_data.fn)
        end
    else
        if viewer_map[user] and not on_cooldown(user, "falando") then
            add_cooldown(user, "falando", 2)
            enqueue(user, command_map.def)
        end
    end
end

local MAX_COMMANDS_PER_TICK = 10
local function execute()
    for _ = 1, MAX_COMMANDS_PER_TICK do
        if #command_queue == 0 then
            break
        end
        local command = table.remove(command_queue, 1)
        command.fn(command.user)
    end
end

local function tick(delta)
    decrement_cooldown(delta)
    execute()
end

-- =========================

local function falando(user)
    local i = viewer_map[user]
    local name = fylm.defs.viewer .. i
    local rg, tm = 6, 0.15
    sources.move(name, { x = 0, y = -rg }, tm)
    sources.move(name, { x = 0, y = rg }, tm)
    sources.move(name, { x = 0, y = -rg }, tm)
    sources.move(name, { x = 0, y = rg }, tm)
    sources.move(name, { x = 0, y = -rg }, tm)
    sources.move(name, { x = 0, y = rg }, tm)
    sources.move(name, { x = 0, y = -rg }, tm)
    sources.move(name, { x = 0, y = rg }, tm)
end
command_map.def = falando

local function entrar(user)
    local viewers_count = table_count(viewer_map)
    if not viewer_map[user] and viewers_count < fylm.defs.seat_count then
        local i = viewers_count + 1
        viewer_map[user] = i
        local name = fylm.defs.viewer .. i
        sources.create_image(name, fylm.assets_folder .. "viewer_sprite.png")
        fylm.align(name, i)
    end
end
command_map[",entrar"] = { fn = entrar, sitted = false, t = "false" }

local function pipoca(user)
    local name = "pipo" .. string.format("%04x", math.random(0, 0xffff))
    sources.create_image(name, fylm.assets_folder .. "pipoca_spriteplaceholder.png")

    local i = viewer_map[user]
    fylm.align(name, i)

    local to_x = sources.current_scene_size.width / 2
    local mod_x = math.random(sources.current_scene_size.width / 6)
    if math.random(2) == 1 then
        to_x = to_x + mod_x
    else
        to_x = to_x - mod_x
    end

    local to_y = sources.current_scene_size.height / 2
    local mod_y = math.random(sources.current_scene_size.height / 6)
    if math.random(2) == 1 then
        to_y = to_y + mod_y
    else
        to_y = to_y - mod_y
    end

    sources.move_to(name, { x = to_x, y = to_y }, 0.5)
end
command_map[",pipoca"] = { fn = pipoca, sitted = true, t = 3 }

-- ==================================================

local M = {}

M.send = receive
M.tick = tick
M.cleanup = cleanup

return M
