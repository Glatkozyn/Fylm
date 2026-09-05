
local fDebug = require("fDebug")

local scene_created = false
local current_scene_name
local current_scene_size = { width = 0, height = 0 }

local active_animations = {}

-- ==================================================

---@return boolean
local function check_scene()
    local source = obslua.obs_get_source_by_name(current_scene_name)
    local exists
    if source then
        exists = true
        obslua.obs_source_release(source)
    end
    return exists
end

local function get_scene_size(scene)
    current_scene_size.width = obslua.obs_source_get_width(scene)
    current_scene_size.height = obslua.obs_source_get_height(scene)
end

---@param name string
local function create_scene(name)
    if not fDebug.expect(type(name) == "string" and #name > 0, "name") then return end

    current_scene_name = name

    local scene = obslua.obs_scene_create(name)
    if not fDebug.ensure(scene, "scene (" .. name .. ")") then return end

    local source = obslua.obs_scene_get_source(scene)
    if not fDebug.ensure(source, "source (" .. name .. ")") then
        obslua.obs_scene_release(scene)
        return
    end

    scene_created = true
    get_scene_size(source)

    obslua.obs_scene_release(scene)

    fDebug.success(string.format("Cena '%s' criada", name))
end

---@return obs_scene_t|nil
local function get_scene()
    local scene_source = obslua.obs_get_source_by_name(current_scene_name)
    if not fDebug.ensure(scene_source, "scene_source (" .. tostring(current_scene_name) .. ")") then
        return nil
    end

    local scene = obslua.obs_scene_from_source(scene_source)
    obslua.obs_source_release(scene_source)

    if not fDebug.ensure(scene, "scene (" .. tostring(current_scene_name) .. ")") then
        return nil
    end

    return scene
end

---@param name string
---@param image_path string
---@return boolean
local function create_image(name, image_path)
    if not fDebug.expect(type(name) == "string" and #name > 0, "name") then return false end
    if not fDebug.expect(type(image_path) == "string" and #image_path > 0, "image_path") then return false end

    local settings = obslua.obs_data_create()
    obslua.obs_data_set_string(settings, "file", image_path)

    local source = obslua.obs_source_create("image_source", name, settings, nil)
    obslua.obs_data_release(settings)
    if not fDebug.ensure(source, "source (" .. name .. ")") then return false end

    local scene = get_scene()
    if not scene then
        obslua.obs_source_release(source)
        return false
    end

    obslua.obs_scene_add(scene, source)
    obslua.obs_source_release(source)

    fDebug.success(string.format("Imagem '%s' criada a partir de '%s'", name, image_path))
    return true
end

local function set_position(item_name, dest)
    local scene = get_scene()
    if not scene then return false end

    local item = obslua.obs_scene_find_source(scene, item_name)
    if not item then return false end

    local pos = obslua.vec2()
    pos.x = dest.x
    pos.y = dest.y

    obslua.obs_sceneitem_set_pos(item, pos)

    return true
end

---@param item obs_sceneitem_t
---@param item_name string
---@param targetX number
---@param targetY number
---@param time integer
local function queue_move(item, item_name, targetX, targetY, time)
    if not fDebug.expect(type(time) == "number" and time >= 0, "time (" .. item_name .. ")") then
        time = 0
    end

    local anim = active_animations[item_name]

    if anim then
        table.insert(anim.queue, {
            x = targetX,
            y = targetY,
            duration = time
        })
        return
    end

    local pos = obslua.vec2()
    obslua.obs_sceneitem_get_pos(item, pos)

    active_animations[item_name] = {
        name = item_name,

        startX = pos.x,
        startY = pos.y,

        endX = targetX,
        endY = targetY,

        elapsed = 0,
        duration = time,

        queue = {}
    }
end

--- move para posição na tela
---@param item_name string
---@param target_position table
---@param time? integer
---@return boolean
local function move_to(item_name, target_position, time)
    local scene = get_scene()
    if not scene then return end

    local item = obslua.obs_scene_find_source(scene, item_name)
    if not fDebug.ensure(item, "item (" .. tostring(item_name) .. ")") then return false end

    queue_move(
        item,
        item_name,
        target_position.x,
        target_position.y,
        time or 0
    )
    return true
end

--- move (acrescenta/decrementa) a partir da própria posição
---@param item_name string
---@param offset table
---@param time? integer
local function move(item_name, offset, time)
    local scene = get_scene()
    if not scene then return end

    local item = obslua.obs_scene_find_source(scene, item_name)
    if not fDebug.ensure(item, "item (" .. tostring(item_name) .. ")") then return end

    local x
    local y

    local anim = active_animations[item_name]

    if anim then
        x = anim.endX
        y = anim.endY

        if #anim.queue > 0 then
            local last = anim.queue[#anim.queue]

            x = last.x
            y = last.y
        end
    else
        local pos = obslua.vec2()

        obslua.obs_sceneitem_get_pos(item, pos)

        x = pos.x
        y = pos.y
    end

    queue_move(
        item,
        item_name,
        x + offset.x,
        y + offset.y,
        time or 0
    )
end

---@param sceneitem_name string|nil
---@return boolean
local function destroy(sceneitem_name)
    local scene = get_scene()
    if not scene then return false end

    local sceneitem = obslua.obs_scene_find_source_recursive(scene, sceneitem_name)
    if not fDebug.ensure(sceneitem, "sceneitem (" .. tostring(sceneitem_name) .. ")") then return false end

    local source = obslua.obs_sceneitem_get_source(sceneitem)
    if not fDebug.ensure(source, "source (" .. tostring(sceneitem_name) .. ")") then return false end

    obslua.obs_source_remove(source)

    fDebug.success(string.format("Fonte '%s' destruída", tostring(sceneitem_name)))
    return true
end

local function tick_moves(delta)
    if not scene_created or next(active_animations) == nil then
        return
    end

    local scene = get_scene()
    if not scene then return end

    for item_name, anim in pairs(active_animations) do
        local item = obslua.obs_scene_find_source(scene, item_name)

        if not item then
            fDebug.warn(
                string.format(
                    "Item '%s' não encontrado durante animação; removendo",
                    item_name
                )
            )

            active_animations[item_name] = nil
        else
            local ok = fDebug.protect(function()
                anim.elapsed = anim.elapsed + delta

                local t

                if anim.duration <= 0 then
                    t = 1
                else
                    t = math.min(
                        anim.elapsed / anim.duration,
                        1
                    )
                end

                local pos = obslua.vec2()

                pos.x = anim.startX + (anim.endX - anim.startX) * t
                pos.y = anim.startY + (anim.endY - anim.startY) * t

                obslua.obs_sceneitem_set_pos(item, pos)

                if t >= 1 then
                    if #anim.queue > 0 then
                        local next_move = table.remove(anim.queue, 1)

                        anim.startX = anim.endX
                        anim.startY = anim.endY

                        anim.endX = next_move.x
                        anim.endY = next_move.y

                        anim.elapsed = 0
                        anim.duration = next_move.duration
                    else
                        active_animations[item_name] = nil
                        -- ##########
                        if string.find(item_name, "pipo") then
                            destroy(item_name)
                        end
                        -- ##########
                    end
                end
            end, "tick:" .. item_name)

            if not ok then
                active_animations[item_name] = nil
            end
        end
    end
end


local M = {}

M.current_scene_size = current_scene_size
M.check_scene = check_scene
M.create_scene = create_scene
M.create_image = create_image
M.set_position = set_position
M.destroy = destroy
M.move = move
M.move_to = move_to
M.tick = tick_moves

return M
