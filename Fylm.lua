
local json = require("dkjson")
local fDebug = require("fDebug")

local sources = require("sources")
local commands = require("commands")

local twitch = require("connection.twitch")

-- =========================

_G.fylm = { defs = {}, setts = {} }
fylm.assets_folder = script_path() .. "assets/"

-- ==================================================

local function updata(str)
    local obj, pos, err = json.decode(str, 1, json.null)
    if err then
        -- print("dkjson error:", err)
        return
    end
    return obj
end

-- =========================

local function treat_receive()
    for _ = 1, 50 do
        local user, msg = twitch.listen()
        if not user then
            break
        end

        local pri = msg:match("^([^ ]+)")
        commands.send(user, pri)
    end
end

local function connection(properties, property)
    local ret1, ret2 = twitch.connect(fylm.setts.channel_name)
    if not ret1 then
        fDebug.error(ret2)
        return
    end

    fDebug.success("conexão twitch online")

    obslua.timer_add(treat_receive, 500)
end

local function disconnection(properties, property)
    if twitch.disconnect() then
        fDebug.warn("conexão twitch desonline")
        obslua.timer_remove(treat_receive)
        commands.cleanup()
        if sources.check_scene() then
            for i = 1, fylm.defs.seat_count do
                if not sources.destroy(fylm.defs.viewer .. i) then
                    return
                end
            end
        end
    else
        fDebug.warn("conexão twitch já está desonline")
    end
end

-- =========================

local function align(name, idx)
    local alignment_y = 0
    local alignment = fylm.setts.seats_alignment or fylm.defs.seats_alignment
    if alignment == "low" then
        alignment_y = sources.current_scene_size.height - 64
    end
    if not idx then
        idx = 1
    end
    local pos = {
        x = 512 + (96 * idx),
        y = alignment_y
    }
    return sources.set_position(name, pos)
end
fylm.align = align

local function realign_seats()
    if not sources.check_scene() then
        return
    end

    for i = 1, fylm.defs.seat_count do
        align("seat" .. i, i)
    end
    for i = 1, fylm.defs.seat_count do
        if not align(fylm.defs.viewer .. i, i) then
            return
        end
    end
end

local function add_seat(i)
    sources.create_image("seat" .. i, fylm.assets_folder .. "assento_sprite.png")
    align("seat" .. i, i)
end

-- local function create_seat(properties, property)
--     add_seat(data.defs.seat_count)
-- end

local function create_fylm_scene(properties, property)
    if sources.check_scene() then
        return
    end

    sources.create_scene(fylm.defs.room)
    for i = 1, fylm.defs.seat_count, 1 do
        add_seat(i)
    end
end

-- ==================================================

function script_description()
    return "Plugin/Script para maior interação do chat em lives de filme muito legal e maneiro do glat. :D"
end

function script_properties()
    local props = obslua.obs_properties_create()

    obslua.obs_properties_add_text(
        props,
        "channel_name",
        "Nome do canal da twitch",
        obslua.OBS_TEXT_DEFAULT
    )

    obslua.obs_properties_add_button(
        props,
        "twitch.connect",
        "Abrir Sala (conectar ao chat)",
        connection
    )

    obslua.obs_properties_add_button(
        props,
        "twitch.disconnect",
        "Fechar Sala (desconectar ao chat)",
        disconnection
    )

    -- =========================

    local room_props = obslua.obs_properties_create()

    obslua.obs_properties_add_button(
        room_props,
        "create_fylm_room",
        "Criar cena",
        create_fylm_scene
    )

    local alinhamentos_prop = obslua.obs_properties_add_list(
        props,
        "seats_alignment",
        "Alinhamento de assentos",
        obslua.OBS_COMBO_TYPE_LIST,
        obslua.OBS_COMBO_FORMAT_STRING
    )
    obslua.obs_property_list_add_string(alinhamentos_prop, "Cima", "high")
    obslua.obs_property_list_add_string(alinhamentos_prop, "Baixo", "low")

    obslua.obs_properties_add_text(
        room_props,
        "VEM_AI",
        "EM BREVE - Botão de Adicionar e Remover assento",
        obslua.OBS_TEXT_INFO
    )

    obslua.obs_properties_add_group(
        props,
        "room_management_group",
        "Sala de Fylm",
        obslua.OBS_GROUP_NORMAL,
        room_props
    )

    -- =========================

    obslua.obs_properties_add_bool(
        props,
        "fDebug",
        "logs"
    )

    return props
end

function script_defaults(settings)
    obslua.obs_data_set_default_string(settings, "channel_name", "")
    obslua.obs_data_set_default_string(settings, "room", "Sala de Fylm")
    obslua.obs_data_set_default_string(settings, "viewer", "Pulha")
    obslua.obs_data_set_default_int(settings, "seat_count", 5)
    obslua.obs_data_set_default_string(settings, "seats_alignment", "low")
    obslua.obs_data_set_default_bool(settings, "fDebug", false)
end

function script_load(settings)
    local defs_str = obslua.obs_data_get_json(obslua.obs_data_get_defaults(settings))
    fylm.defs = updata(defs_str)

    local setts_str = obslua.obs_data_get_json(settings)
    fylm.setts = updata(setts_str)

    fDebug.enabled(fylm.setts.fDebug or fylm.defs.fDebug)

    sources.load({ current_scene_name = fylm.defs.room })

    math.randomseed(os.time())
end

function script_update(settings)
    local setts_str = obslua.obs_data_get_json(settings)

    local old_align = fylm.setts.seats_alignment or nil
    local old_fDebug = fylm.setts.fDebug or nil
    local old_room = fylm.setts.room or nil

    fylm.setts = updata(setts_str)

    if old_align ~= fylm.setts.seats_alignment then
        realign_seats()
    end
    fDebug.enabled(fylm.setts.fDebug)
end

function script_tick(delta)
    commands.tick(delta)
    sources.tick(delta)
end
