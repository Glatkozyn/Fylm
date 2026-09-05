
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

local function connection(properties, property)
    twitch.connect(fylm.setts.channel_name)

    local function treat_receive()
        local ret1, ret2 = twitch.listen()
        local user, msg
        if not ret1 then
            -- print("error:" .. ret2)
        else
            user, msg = ret1, ret2
        end
        if user and msg then
            -- print(user .. ":" .. msg)
            local pri = msg:match("^([^ ]+)")
            commands.send(user, pri)
        end
    end

    obslua.timer_add(treat_receive, 500)
end

local function disconnection(properties, property)
    twitch.disconnect()
end

-- =========================

local function align(name, idx)
    local alignment_y = 0
    local alignment = fylm.setts.sits_alignment or fylm.defs.sits_alignment
    if alignment == "low" then
        alignment_y = sources.current_scene_size.height - 64
    end
    local pos = {
        x = 512 + (96 * idx),
        y = alignment_y
    }
    return sources.set_position(name, pos)
end
fylm.align = align

local function realign_sits()
    if not sources.check_scene then
        return
    end
    for i = 1, fylm.defs.sit_count do
        align("sit" .. i, i)
    end
    for i = 1, fylm.defs.sit_count do
        if not align(fylm.defs.viewer .. i, i) then
            return
        end
    end
end

local function add_sit(i)
    sources.create_image("sit" .. i, fylm.assets_folder .. "assento_sprite.png")
    align("sit" .. i, i)
end

-- local function create_sit(properties, property)
--     add_sit(data.defs.sit_count)
-- end

local function create_fylm_scene(properties, property)
    sources.create_scene(fylm.defs.room)
    for i = 1, fylm.defs.sit_count, 1 do
        add_sit(i)
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
        "sits_alignment",
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
    obslua.obs_data_set_default_int(settings, "sit_count", 5)
    obslua.obs_data_set_default_string(settings, "sits_alignment", "low")
    obslua.obs_data_set_default_bool(settings, "fDebug", true)
end

function script_load(settings)
    local defs_str = obslua.obs_data_get_json(obslua.obs_data_get_defaults(settings))
    fylm.defs = updata(defs_str)

    local setts_str = obslua.obs_data_get_json(settings)
    fylm.setts = updata(setts_str)

    fDebug.enabled = fylm.setts.fDebug or fylm.defs.fDebug
end

function script_update(settings)
    local setts_str = obslua.obs_data_get_json(settings)

    local old_align = fylm.setts.sits_alignment or nil
    local old_fDebug = fylm.setts.fDebug or nil

    fylm.setts = updata(setts_str)

    if old_align ~= fylm.setts.sits_alignment then
        realign_sits()
    end
    if old_fDebug ~= fylm.setts then
        fDebug.enabled = fylm.setts.fDebug
    end
end

function script_tick(delta)
    commands.tick(delta)
    sources.tick(delta)
end
