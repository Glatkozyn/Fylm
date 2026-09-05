
local sources = require("sources")

-- ==================================================

local viewer_map = {}

local function table_count(t)
    local count = 0

    for _ in pairs(t) do
        count = count + 1
    end

    return count
end

local function add_cooldown(user, command, time)
    if not viewer_map[user] then
        return
    end

    viewer_map[user].cooldown = viewer_map[user].cooldown or {}
    viewer_map[user].cooldown[command] = time or 0.5
end

local function decrement_cooldown(delta)
    for _, viewer in pairs(viewer_map) do
        local cooldown = viewer.cooldown

        if cooldown then
            for command, time in pairs(cooldown) do
                time = time - delta

                if time <= 0 then
                    cooldown[command] = nil
                else
                    cooldown[command] = time
                end
            end
        end
    end
end

local command_map = {}
local queue = {}

local function enqueue(user, fn)
    table.insert(queue, { user = user, fn = fn })
end

local MAX_COMMANDS_PER_TICK = 10
local function execute()
    for _ = 1, MAX_COMMANDS_PER_TICK do
        if #queue == 0 then
            break
        end

        local command = table.remove(queue, 1)
        command.fn(command.user)
    end
end

local function receive(user, inimsg)
    print("recebido")
    local fn = command_map[inimsg]
    if fn then
        enqueue(user, fn)
    else
        if viewer_map[user] and not viewer_map[user].cooldown["falando"] then
            enqueue(user, command_map.def)
        end
    end
end

local function tick(delta)
    execute()
    decrement_cooldown(delta)
end

-- ==================================================

local function entrar(user)
    print("entrado: " .. user)
    local viewers_count = table_count(viewer_map)
    if not viewer_map[user] and viewers_count < fylm.defs.sit_count then
        local i = viewers_count + 1
        viewer_map[user] = { idx = i, cooldown = {} }
        local name = fylm.defs.viewer .. i
        sources.create_image(name, fylm.assets_folder .. "viewer_sprite.png")
        fylm.align(name, i)
    end
end
command_map[",entrar"] = entrar

local function falando(user)
    local command_id = "falando"
    local i = viewer_map[user].idx
    local name = fylm.defs.viewer .. i
    sources.move(name, { x = 0, y = -8 }, 0.5)
    sources.move(name, { x = 0, y = 8 }, 0.25)
    sources.move(name, { x = 0, y = -8 }, 0.25)
    sources.move(name, { x = 0, y = 8 }, 0.25)
    sources.move(name, { x = 0, y = -8 }, 0.25)
    sources.move(name, { x = 0, y = 8 }, 0.25)
    add_cooldown(user, command_id)
end
command_map.def = falando

local function pipoca(user)
    local command_id = "pipoca"
    if viewer_map[user] and not viewer_map[user].cooldown[command_id] then

        local name = "pipo" .. math.random(100)
        sources.create_image(name, fylm.assets_folder .. "pipoca_spriteplaceholder.png")

        local i = viewer_map[user].idx
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

        add_cooldown(user, command_id)
    end
end
command_map[",pipoca"] = pipoca

-- ==================================================

local M = {}

M.send = receive
M.tick = tick

return M
