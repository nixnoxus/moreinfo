-- init.lua moreinfo

moreinfo =
    { _debug = false
    , _experimental = false
    , text_color = '#E0D0A0'
    , game_info = nil
    }

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

if moreinfo._experimental then
    dofile(modpath .. "/facing.lua")
end

local function debug(msg)
    if moreinfo._debug then print(msg) end
end

local function enabled(key)
     return minetest.settings:get_bool(modname .. "." .. key) ~= false
end

local function template_fill(fmt, hash, key_name_func)
    local positions = {}
    local pos2key = {}
    for k in pairs(hash) do
        local i = string.find(fmt, key_name_func(k))
        if i then
            positions[#positions+1] = i
            pos2key[i] = k
        end
    end
    table.sort(positions)
    local offset = 0
    for _, i in ipairs(positions) do
        local key = pos2key[i]
        local val = hash[key]
        local key_len = string.len(key_name_func(key))
        fmt = string.sub(fmt, 1, offset + i -1) .. val .. string.sub(fmt, offset + i + key_len)
        offset  = offset + string.len(val) - key_len
    end

    return fmt
end

local function chat_send_player(player_name, msg)
    -- chat_message_format = @timestamp @name: @message
    local fmt = minetest.settings:get("chat_message_format")
    if fmt then
        msg = template_fill(fmt,
            { timestamp = os.date("%X")
            , name      = "[" .. modname .. "]"
            , message   =  msg
            }, function(k) return "@" .. k end)
        debug("chat: " .. msg)
    end

    if INIT == "client" then
        minetest.display_chat_message(msg)
    elseif INIT == "game" then
        minetest.chat_send_player(player_name, msg)
    end
end

local function vector2str(v)
    if not v then return "?,?,?" end
    return v.x .. "," .. v.y .. "," .. v.z
end

local function vector2strf(fmt, v)
    if not v then return "?,?,?" end
    return string.format(fmt, v.x) .. "," .. string.format(fmt, v.y) .. "," .. string.format(fmt, v.z)
end

local function vector2str_1(v) return vector2strf("%.1f", v) end

local function try_keys(list, ...)
    local ret,i = "", 0
    for i = 1, select('#', ...) do
        local key = select(i, ...)
        if list[key] ~= nil then
            ret = ret .. " " .. key .. "=" .. (list[key] or "")
        end
    end
    return ret
end

local huds = {}

local function hud_init()
    return
        { standing =
            { id = nil
            , def =
                { hud_elem_type = 'text'
                , position  = { x = 0, y = 1 }
                , alignment = { x = 1, y = -1 }
                , offset = { x = 3, y = 0 }
                , text = nil
                , scale = { x = 100, y = 100 }
                , number = moreinfo.text_color:gsub('#', '0x')
                }
            }
        , looking =
            { id = nil
            , def =
                { hud_elem_type = 'text'
                , position  = { x = 0.5, y = 0.4 } -- 0 .. 1
                , alignment = { x = 0, y = -1 }  -- -1 .. +1
                , text = nil
                , scale = { x = 50, y = 100 }
                , number = moreinfo.text_color:gsub('#', '0x')
                }
            }
        }
end

local function hud_show(h, player, text)
    h.def.text = text
    if not h.id then
        h.id = player:hud_add(h.def)
    else
        player:hud_change(h.id, 'text', text)
    end
end

local function human_s(s)
    local units =    { "s", "m", "h", "d", "w" }
    local divisors = {  60,  60,  24,  7,   0  }
    local str = ""
    local i = 1
    s = math.floor(s)
    while (i <= #units and (s ~= 0 or i == 1)) do
        local v
        if divisors[i] == 0 then
            v = s
        else
            v = s % divisors[i]
            s = (s - v) / divisors[i]
        end
        str = v .. units[i] .. str
        i = i + 1
    end
    return str
end

local function hud_update_global()
    if not enabled("display_game_info") then return end

    local t = minetest.get_timeofday() * 24
    local h = math.floor(t)
    local m = math.floor((t-h) * 60)

    local players = minetest.get_connected_players()
    local names = {}
    table.foreach(players, function(i,p)
        local player_name = p:get_player_name()
        names[i] = player_name -- .. "[" .. minetest.get_player_information(player_name).avg_rtt .. "]"
    end)

    moreinfo.game_info = "time: " .. string.format("%2d:%02d", h, m)
        .. " players: " .. #players
        .. " (" .. table.concat(names, ",") .. ")"
--        .. " uptime: " .. human_s(minetest.get_server_uptime())
end

local function hud_update_player(player)
    local player_name = player:get_player_name()
    local hud = huds[player_name]

    hud.last =
        { pos   = hud.pos
        , ipos  = hud.ipos
        , utime = hud.utime
        , speed = hud.speed
        }

    hud.pos   = player:get_pos()
    hud.utime = minetest.get_us_time()

    -- first call
    if not hud.last.pos then
        hud.speed = 0
    else
        hud.udelta = (hud.utime - hud.last.utime)
        hud.speed = vector.distance(hud.pos, hud.last.pos) / ( hud.udelta / 1000000 )
    end

    if hud.last.pos and hud.speed == 0 then
        hud.stand = (hud.stand or 0) + hud.udelta
    else
        hud.stand = 0
        hud.stand_loop = 0
        hud.rpos = vector.round(hud.pos)
        hud.mpos = vector.apply(hud.rpos, function(v) return math.floor(v / 16) end)
        hud.opos = vector.apply(hud.rpos, function(v) return v % 16 end)
    end

    return hud
end

local function do_hud(player)
        local hud = hud_update_player(player)

	local msg = "pos: " .. vector2str(hud.rpos)
            .. "\nmap block: " .. vector2str(hud.mpos)
            .. " offset: " .. vector2str(hud.opos)

        if hud.speed ~= 0 or not moreinfo._experimental then
            msg = msg .. "\nspeed: " .. string.format("%.2f", hud.speed)
        else
            msg = msg .. "\nstand: " .. math.floor(hud.stand / 1000000 + 0.5) .. " loop: " .. hud.stand_loop
        end

        hud.light = minetest.get_node_light(hud.pos)
        if hud.light then
            local l1 = minetest.get_node_light(hud.pos, 0)
            local l2 = minetest.get_node_light(hud.pos, 0.5)
            msg = msg .. "\nlight: " .. string.format("%d (%d..%d)", hud.light, l1, l2)
        end

        if not enabled("display_position_info") then
            msg = ""
        elseif moreinfo.game_info then
            msg = msg .. "\n"
        end

        hud_show(hud.standing, player, msg .. (moreinfo.game_info or ""))

        if not moreinfo._experimental then return end

        if hud.speed ~= 0 then
            if hud.last.speed ~= 0 then hud_show(hud.looking, player, "") end
            return
        end

        if INIT == "client" then
            local n = minetest.get_node_or_nil(hud.pos)
            msg = msg .. "\n" .. (n and n.name or "")
            n = minetest.get_node_or_nil(vector.subtract(hud.pos, { x = 0, y = 1, z = 0 }))
            msg = msg .. "\n" .. (n and n.name or "")
        elseif false then
--        elseif true then
            msg = msg .. "\n".. dump(facing(player, true, true))
--            msg = msg .. "\n".. dump(facing(player, true))
        else
            local msg = ""
            local f = facing(player)
            if not f or not f.under then

                local objs = minetest.get_objects_inside_radius(hud.pos, 15)
                msg = "items around 15 blocks:" .. #objs
                if #objs > 0 then
                    hud.stand_loop = hud.stand_loop +1
                end

                for i, obj in ipairs(objs) do
                    if not obj then
                        msg = msg .. "\n" .. i .. " nix obj"
                    else
                        msg = msg .. "\n" .. i .. " " .. vector2str_1(obj:get_pos())
                            .. try_keys(obj, "name", "type", "description")

                        if obj:is_player() then
                            msg = msg .. " player: " .. obj:get_player_name() or '?'
                        else
                            local entity = obj:get_luaentity()
                            if hud.stand_loop == 1 then
                                    print("object ".. i)
                                    -- print(" obj:" .. dump(obj))
                                    print(" entity:" .. dump(entity))

                                    if false then
                                        local txt = ""
                                        for k,v in pairs(entity) do
                                            txt = txt .. "\n" .. (k or "") --.. "=" .. (v or "")
                                        end
                                        print(" txt:" .. txt)
                                    end
                            --        print(" entity.object:" .. dump(entity.object))
                            end

                            if not entity then
                                msg = msg .. " nix entity"
                            else
                                if entity._cmi_is_mob then
                                    msg = msg .. " [mob "..(entity["type"] or "").."]"
                                end
                                msg = msg .. try_keys(entity, "name", "itemstring", "type", "description")
                            end
                        end
                    end
                end

                if hud.stand_loop == 1 then
                    print(msg)
                end

                hud_show(hud.looking, player, msg)
                return
            end

            local fpos = f.under
            hud.ipos = f.intersection_point
--                ipos = f.above

            if hud.ipos then
                msg = msg .. "\nipos: " .. vector2str_1(hud.ipos)

                local objs = minetest.get_objects_inside_radius(hud.ipos, .5)
                if #objs >= 1 then
                     msg = msg .. "\nobj(1/"..#objs.."): "
                    if not objs[1] then
                        msg = msg .. "nix"
                    elseif objs[1]:is_player() then
                        msg = msg .. "player: " .. objs[1]:get_player_name() or '?'
                    else
                        -- itemstring, age, object, moving_state
                        local entity = objs[1]:get_luaentity()
--[[
                        if entity then
                            local e = entity:get_luaentity()
                            if e then entity = e end
                        end
--]]
                        if not entity then
                            msg = msg .. "nix entity"
                        elseif entity.name == "__builtin:item" and entity.itemstring ~= "" then
                            msg = msg .. "entity.itemstring " .. entity.itemstring
                                .. " [-" .. (900 - math.floor(entity.age)) .. "s]"
                        elseif entity.name or entity.itemstring then
                            msg = msg .. "entity.name:" .. (entity.name or "")
                                    .. " .itemstring:" .. (entity.itemstring or "")
                        else
                            local to_chat, err = pcall(function () return dump(objs[1]) end)
                            local to_chat, err = pcall(function () return dump(objs[1]:get_meta()) end)
--                            local to_chat, err = pcall(function () return dump(objs[1]:get_attach()) end)
--                            local to_chat, err = pcall(function () return dump(objs[1]:hud_get()) end)
--                            local to_chat, err = pcall(function () return dump(objs[1]:get_properties()) end)
--                            local to_chat, err = pcall(function () return dump(entity) end)
                            if not err then
                                msg = msg .. "dump: ^"
                            else
                                msg = msg .. "err: ^"
                                to_chat = err
                            end

                            if not hud.last.ipos or not vector.equals(hud.last.ipos, hud.ipos) then
                                chat_send_player(player:get_player_name(), "dump:" .. to_chat)
                                print(to_chat)
                            end

--                                minetest.display_chat_message(d) --csm
                        end
                    end

                    hud_show(hud.looking, player, msg)
                    return
                end
            end

            msg = msg .. "\nfacing: " .. vector2str(fpos)
            local n = minetest.get_node_or_nil(fpos)
            if n then
                msg = msg .. "\nnode: " .. (n.name or "")
                    .. " (" .. (n.param1 or "-")
                    .. "," .. (n.param2 or "-")
                    .. ")"
            end

            hud_show(hud.looking, player, msg)
            return
        end
end

local function died(dead_player, msg_part)
    local pos = vector.round(dead_player:get_pos())
    local msg = "You " .. (msg_part or "died") .. " at " .. minetest.pos_to_string(pos) .. "."
    chat_send_player(dead_player:get_player_name(), minetest.colorize("#E0D0A0", msg))
end

local function get_description(name)
    if not name then
        return name
    elseif minetest.registered_nodes[name] then
        return minetest.registered_nodes[name].description or name
    elseif minetest.registered_entities[name] then
        return minetest.registered_entities[name].description or name
    else
        return name
    end
end

local function player_or_mob(obj)
    if not obj then
        return nil
    elseif obj:is_player() then
        return obj:get_player_name()
    else
        local entity = obj:get_luaentity()
        if entity and entity._cmi_is_mob and entity.name then
            return (minetest.registered_entities[entity.name] and minetest.registered_entities[entity.name].description)
                or (minetest.registered_craftitems[entity.name] and minetest.registered_craftitems[entity.name].description)
                or entity.name or "?"
        else
            return get_description(entity.name) or "?"
        end
    end
end

--[[

    minetest.register_on_punchnode(function(pos, node)
            minetest.display_chat_message("Node name: " .. node.name
                .. " Param1: " .. tostring(node.param1)
                .. " Param2, Facedir: " .. tostring(node.param2) .. ", " .. tostring(node.param2 % 32))
    end

    minetest.register_on_mods_loaded(function() print("mods loaded:" .. (minetest.localplayer or '?') ) end)
    minetest.register_on_step(function() print("step") end)
    minetest.register_on_joinplayer(function() print("join player") end)
    minetest.register_on_connect(function() localplayer = minetest.localplayer end) -- csm fail
--]]

local timer = 0

debug("init " .. modname .. " " .. INIT or '?')


if INIT == "client" then

    debug(" csm restrictions" .. dump(minetest.get_csm_restrictions()))

    local player = minetest.localplayer
    huds[player:get_player_name()] = hud_init()

    -- FIXME:?
    minetest.register_on_connect(function()
        minetest.after(0.1, function()
            minetest.ui.minimap:show()
        end)
    end)

    minetest.register_on_death(function()
	died(minetest.localplayer)
    end)

    minetest.register_globalstep(function(dtime)
        timer = timer + dtime
        if timer < .3 then return end
        timer = 0
        hud_update_global()
        do_hud(minetest.localplayer)

--        print(dump(player:get_player_control_bits())) -- fail
--        print(dump(player:get_key_pressed())) -- fail
--        print(dump(player:get_control())) -- okay
--	minetest.display_chat_message(minetest.colorize(color, msg))
    end)

elseif INIT == "game" then

    if enabled("public_death_messages") then
        -- Note: chat message "You died." already removed from core
        --  see: https://github.com/minetest/minetest/pull/11443/files
        minetest.register_on_dieplayer(function(dead_player, reason)
            local dead_player_name = dead_player:get_player_name()
            local msg_part
            debug("dead reason:" .. dump(reason))
            if reason.type == "punch" then
                debug(" object:" .. (reason.object.name or '-'))
                local killer = player_or_mob(reason.object)
                if killer then
                    msg_part = "killed by " .. killer
                end
            elseif reason.type == "node_damage" then
                msg_part = "killed by " .. (get_description(reason.node) or "?")
            else -- reason.type: { fall | drown | respawn }
                msg_part = "died by " .. (reason.type or "?")
            end

            -- `minetest.chat_send_all(text)
            for _, player in pairs(minetest.get_connected_players()) do
                if (player == dead_player) then
                    died(dead_player, msg_part or "died")
                else
                    chat_send_player(player:get_player_name()
                        , dead_player_name .. " " .. (msg_part or "died")
                        )
                end
            end
        end)

    end

--[[ minetest.conf: chat_message_format = @timestamp @name: @message

    minetest.register_on_chat_message(function(name, message)
        if name and message then
           minetest.chat_send_all(os.date("%X") .. " " .. name .. ": " .. message)
           return true
        end
    end)
--]]

    minetest.register_on_joinplayer(function(player)
        huds[player:get_player_name()] = hud_init()
        local v = minetest.get_version()
        chat_send_player(player:get_player_name()
            , "Welcome to " .. v.project .. " " .. (v.hash or v.string)
            .. " uptime: " .. human_s(minetest.get_server_uptime())
            )
--        player:hud_set_flags({ minimap = true, minimap_radar =  true })
    end)

    minetest.register_on_leaveplayer(function(player)
        huds[player:get_player_name()] = nil
    end)

--[[
    minetest.register_chatcommand("test", {
        params = nil,
        description = "test ..",
        func = function()
            local camera = minetest.camera
            points["test"] = {
                pos = camera:get_pos(),
                dir = camera:get_look_dir()
            }
            return true, "so"
        end,
    })
--]]
    minetest.register_globalstep(function(dtime)
        timer = timer + dtime
        if timer < .3 then return end
        timer = 0
        hud_update_global()

        for _, player in pairs(minetest.get_connected_players()) do
            do_hud(player)
        end
    end)
end
