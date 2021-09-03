-- init.lua moreinfo

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)

moreinfo =
    { version = "1.1.0"
    , _debug = false
    , _experimental = false
    -- FIXME: ssm vs. csm
    , text_color = ((INIT == "client") and '#8080E0' or'#E0D0A0')
    , game_info = nil
    , players_info = nil
    , players_long_info = nil -- FIXME: testing ...
    , bones_limit = (INIT == "game") and tonumber(minetest.settings:get(modname .. ":bones_limit")) or 3
    }

if moreinfo._experimental then
    dofile(modpath .. "/facing.lua")
end

-- common functions

local function debug(msg)
    if moreinfo._debug then print(msg) end
end

local function oops(msg)
    print("[" .. modname .. "] oops: " .. msg)
end

local function enabled(key, player)
    if INIT == "client" then
        return true
    else
        local meta = player and player:get_meta() or nil
        local key = modname .. ":" .. key
        if meta and meta:contains(key) then
            return meta:get_int(key) == 1
        else
            return minetest.settings:get_bool(key) ~= false
        end
    end
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
    if INIT == "game" then
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
    end

    if INIT == "client" then
        minetest.display_chat_message(msg)
    elseif INIT == "game" then
        minetest.chat_send_player(player_name, msg)
    end
end

local function get_player_name(player)
    if INIT == "client" then
        return "client"
    elseif INIT == "game" then
        return player:get_player_name()
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

local function get_meta(meta, key, default)
    local json = meta and meta:get(modname .. ":" .. key)
    return json and minetest.deserialize(json) or default
end

local function set_meta(meta, key, value)
    local rc = meta and meta:set_string(modname .. ":" .. key, minetest.serialize(value))
end

-- way points (csm & ssm)

local wps = {}

local function wp_init(player)
    local player_name = get_player_name(player)
    local meta = (INIT == "game") and player:get_meta() or nil

    wps[player_name] =
        { bone_next = get_meta(meta, "bone_next", 1)
        , bones_pos = get_meta(meta, "bones_pos", {})
        , bones_hid = {}
        , bed_hid = nil
        }
    debug("init wp_bones next: " .. wps[player_name].bone_next)
end

local function wp_add(player, name, world_pos)
    return player:hud_add(
        { hud_elem_type = "waypoint"
        , name = name
        , world_pos = world_pos
        , text = "m"
        , precision = 1
        , number = ((INIT == "game") and "0xffcccc" or "0xaa0088")
        })
end

local function wp_info(player, hid, to_pos)
    local hud = hid and player:hud_get(hid)
    if hud and to_pos then
        local d = hud.world_pos and math.floor(vector.distance(hud.world_pos, to_pos)) or '?'
        return hud.name .. ": " ..  d .. hud.text
    end
end

local function wp_info_all(player, player_name, to_pos)
    local i
    local m = {}
    for i = 0, #wps[player_name].bones_pos do
        local hid = (i == 0) and wps[player_name].bed_hid or wps[player_name].bones_hid[i]
        m[#m + 1] = wp_info(player, hid, to_pos)
    end

    return #m and table.concat(m, "\n") .. "\n"
end

-- way point bed (ssm only)

local function update_wp_bed(player, player_name)
    debug("update_wp_bed ..")
    player_name = player_name or player:get_player_name()
    local spawn = enabled("waypoint_bed", player) and beds.spawn[player_name]

    if spawn then
        debug(" spawn " .. dump(spawn))
        if not wps[player_name].bed_hid then
            debug(" add wp bed")
            wps[player_name].bed_hid = wp_add(player, "spawn (bed)", spawn)
        else
            player:hud_change(wps[player_name].bed_hid, 'world_pos', spawn)
        end
    else
        if wps[player_name].bed_hid then
            player:hud_remove(wps[player_name].bed_hid)
            wps[player_name].bed_hid = nil
        end
        debug(" nix beds.spawn")
    end
end

-- way points bones (csm & ssm)

local function update_wp_bones(player, player_name)
    player_name = player_name or player:get_player_name()
    local max = #wps[player_name].bones_pos
    local suffix = (INIT == "client") and "?" or ""

    for i =1, max do
        if wps[player_name].bones_hid[i] then
            player:hud_remove(wps[player_name].bones_hid[i])
        end

        wps[player_name].bones_hid[i] =
            enabled("waypoint_bones", player) and wp_add(player
                , "bones[" .. i .. "/" .. max .. "]" .. suffix
                , wps[player_name].bones_pos[i]
                )
    end

    if (INIT == "client") then return end
    local meta = player:get_meta() or nil
    set_meta(meta, "bones_pos", wps[player_name].bones_pos)
    set_meta(meta, "bone_next", wps[player_name].bone_next)
end

local function check_wp_bones(player, player_name)
    debug("checked wp_bones"
        .. " count:" .. #wps[player_name].bones_pos
        .. " next: " .. wps[player_name].bone_next
        )
    local i = 1
    while (i <= #wps[player_name].bones_pos) do
        local pos = wps[player_name].bones_pos[i]
        local name = pos and minetest.get_node(pos).name
        debug(" check bones " .. i .. " " .. vector2str(pos) .. " " .. (name or "-"))
        if not pos or (name ~= "bones:bones" and name ~= "ignore") then
            debug(" remove bones " .. i)
            if wps[player_name].bones_hid[i] then
                player:hud_remove(wps[player_name].bones_hid[i])
            end
            table.remove(wps[player_name].bones_pos, i)
            table.remove(wps[player_name].bones_hid, i)
            if wps[player_name].bone_next > i then
                wps[player_name].bone_next = wps[player_name].bone_next -1
            end
        else
            i = i +1
        end
    end
    debug(" checked wp_bones"
        .. " count:" .. #wps[player_name].bones_pos
        .. " next: " .. wps[player_name].bone_next
        )
end

local function add_wp_bones(player_name, pos)
    if INIT == "game" then
        if minetest.is_creative_enabled(player_name) then
            oops("no bones (creative)")
            return
        end
        local node = minetest.get_node(pos)
        if node.name ~= "bones:bones" then
            oops("no bones found")
            return
        end
    else
        pos.y = pos.y + 1 -- FIXME: ssm vs. csm
    end

    local i = ((wps[player_name].bone_next -1) % moreinfo.bones_limit) +1
    if i > #wps[player_name].bones_pos +1 then
        i = #wps[player_name].bones_pos +1
    end

    debug("add bones " .. i);
    wps[player_name].bones_pos[i] = pos
    wps[player_name].bone_next = i + 1
end

-- hud

local huds = {}
local function hud_init()
    local hud =
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

    -- FIXME: ssm vs. csm
    if INIT == "client" then
        hud.standing.def.position.x = 1
        hud.standing.def.alignment.x = -1
    end
    return hud
end

local last_text = ""
local function hud_show(h, player, text)
    h.def.text = text
    if not h.id then
        h.id = player:hud_add(h.def)
    else
        player:hud_change(h.id, 'text', text)
    end
    if text ~= last_text then
--        debug("hud " .. get_player_name(player) .. " " .. string.gsub(text, "\n", ";"))
        last_text = text
    end
end

local function update_game_info()
    local t = minetest.get_timeofday() * 24
    local h = math.floor(t)
    local m = math.floor((t-h) * 60)
    moreinfo.game_info = "time: " .. string.format("%2d:%02d", h, m) .. "\n"
end

local function update_players_info() -- ssm only
    local players = minetest.get_connected_players()

    moreinfo.players_info = "players: " .. #players .. "\n"
    moreinfo.players_long_info = moreinfo.players_info

    table.foreach(players, function(_, p)
        local fmt = "%3.0f"
        local f = 1000
        local player_name = p:get_player_name()
        local player_info = minetest.get_player_information(player_name)
        if not player_info then
            oops("nix player_info:" .. dump(player_info))
            return
        end
        local cols =
            { " " .. player_name .. (minetest.is_creative_enabled(player_name) and "*" or "")
            , " | " .. string.format(fmt, player_info.min_rtt * f)
             .. " " .. string.format(fmt, player_info.avg_rtt * f)
             .. " " .. string.format(fmt, player_info.max_rtt * f)
             .. " | " .. string.format(fmt, player_info.min_jitter * f)
             .. " "  .. string.format(fmt, player_info.avg_jitter * f)
             .. " "  .. string.format(fmt, player_info.max_jitter * f)
             .. " |"
             , " " .. human_s(player_info.connection_uptime) .. "\n"
             }

        moreinfo.players_info = moreinfo.players_info .. cols[1] .. cols[3]
        moreinfo.players_long_info = moreinfo.players_long_info .. cols[1] .. cols[2].. cols[3]
    end)
end

local function hud_update_player(player)
    local player_name = get_player_name(player)
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
        hud.speed_avg = 0
        hud.last_stand_pos = hud.pos
        hud.last_stand_utime = hud.utime
    else
        hud.udelta = (hud.utime - hud.last.utime)
        hud.speed = vector.distance(hud.pos, hud.last.pos) / ( hud.udelta / 1000000 )
    end

    if hud.last.pos and hud.speed == 0 then
        hud.stand = (hud.stand or 0) + hud.udelta
        hud.last_stand_pos = hud.pos
        hud.last_stand_utime = hud.utime
    else
        hud.stand = 0
        hud.stand_loop = 0

        hud.rpos = vector.round(hud.pos)
        hud.mpos = vector.apply(hud.rpos, function(v) return math.floor(v / 16) end)
        hud.opos = vector.apply(hud.rpos, function(v) return v % 16 end)

        if hud.last_stand_pos and hud.last_stand_utime < hud.utime then
            hud.speed_avg = vector.distance(hud.pos, hud.last_stand_pos)
                / ( (hud.utime - hud.last_stand_utime) / 1000000 )
        end
    end

    return hud
end

local function do_hud(player)
    local hud = hud_update_player(player)
    local infos = {}

    if enabled("display_waypoint_info", player) then
        local player_name = get_player_name(player)
        infos[#infos +1] = wp_info_all(player, player_name, hud.pos)
    end

    if enabled("display_position_info", player) then
        local msg = "pos: " .. vector2str(hud.rpos)
            .. "\nmap block: " .. vector2str(hud.mpos)
            .. " offset: " .. vector2str(hud.opos)

        if hud.speed ~= 0 or not moreinfo._experimental then
            msg = msg .. string.format("\nspeed: %.2f avg: %.2f m/s", hud.speed, hud.speed_avg)
        else
            msg = msg .. "\nstand: " .. math.floor(hud.stand / 1000000 + 0.5) .. " loop: " .. hud.stand_loop
        end

        hud.light = minetest.get_node_light(hud.pos)
        if hud.light then
            local l1 = minetest.get_node_light(hud.pos, 0)
            local l2 = minetest.get_node_light(hud.pos, 0.5)
            msg = msg .. string.format("\nlight: %d (%d..%d)", hud.light, l1, l2)
        end

        local b = minetest.get_biome_data(hud.pos)
        if b then
            -- https://dev.minetest.net/minetest.register_biome
            -- TODO: "Heat is not in degrees celcius, both values are abstract."
            --msg = msg .. string.format("\nbiome: %s %d° %d%%"
            msg = msg .. string.format("\nbiome: %s T: %i H: %i"
                , b.biome and minetest.get_biome_name(b.biome) or "?"
                , b.heat
                , b.humidity
                )
        end

        infos[#infos +1] = msg .. "\n"
    end

    table.foreach({ "game_info", "players_info", "players_long_info" }, function(_, opt)
        infos[#infos +1] = enabled("display_" .. opt, player) and moreinfo[opt] or nil
    end)

    hud_show(hud.standing, player, string.gsub(table.concat(infos, "\n"),"\n+$", ""))

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
                                chat_send_player(get_player_name(player), "dump:" .. to_chat)
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

-- misc functions

local function died(dead_player, pos, msg_part)
    local msg = "You " .. (msg_part or "died")
        .. " at " .. minetest.pos_to_string(vector.round(pos)) .. "."
    local player_name = get_player_name(dead_player)
    chat_send_player(player_name, minetest.colorize(moreinfo.text_color, msg))

    add_wp_bones(player_name, pos)
    update_wp_bones(dead_player, player_name)
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

    minetest.get_biome_data = function(...) return end
    --minetest.get_biome_name = function(...) return end

    local player = minetest.localplayer
    debug(" localplayer:"..dump(player))
    huds[get_player_name(player)] = hud_init()
    wp_init(player)
    -- minetest.ui.minimap:show()

    minetest.register_on_death(function()
        local player = minetest.localplayer
	died(player, player:get_pos())
    end)

    minetest.register_globalstep(function(dtime)
        timer = timer + dtime
        if timer < .3 then return end
        timer = 0
    --debug("localplayer:"..dump(player))
        update_game_info()
        do_hud(minetest.localplayer)

--        print(dump(player:get_player_control_bits())) -- fail
--        print(dump(player:get_key_pressed())) -- fail
--        print(dump(player:get_control())) -- okay
--	minetest.display_chat_message(minetest.colorize(color, msg))
    end)

elseif INIT == "game" then

    if minetest.get_modpath("beds") then
        debug("beds.spawn:" .. dump(beds.spawn))

        local orig_on_rightclick = beds.on_rightclick
        beds.on_rightclick = function(pos, player)
            local rc = orig_on_rightclick(pos, player)
            update_wp_bed(player)
            return rc
        end

        local orig_remove_spawns_at = beds.remove_spawns_at
        beds.remove_spawns_at = function(pos)
            local rc = orig_remove_spawns_at(pos)

            local players = minetest.get_connected_players()
            table.foreach(players, function(_,player)
                update_wp_bed(player)
            end)

            return rc
        end
    else
        update_wp_bed = function(...) return end
    end

    if minetest.get_modpath("bones") then
        local name = "bones:bones"
        local orig_on_punch = minetest.registered_nodes[name].on_punch

        minetest.override_item(name, {
          on_punch = function(pos, node, player)
            debug("running bones hook " .. minetest.get_node(pos).name )
            orig_on_punch(pos, node, player)

            local players = minetest.get_connected_players()
            table.foreach(players, function(_,p)
                local n = get_player_name(p)
                check_wp_bones(p, n)
                update_wp_bones(p, n)
            end)
        end })
    else
        check_wp_bones = function(...) return end
        add_wp_bones = function(...) return end
        update_wp_bones = function(...) return end
    end

    minetest.register_on_dieplayer(function(dead_player, reason)
        local dead_player_name = dead_player:get_player_name()
        local pos = dead_player:get_pos()

        if enabled("public_death_messages") then
        -- Note: chat message "You died." already removed from core
        --  see: https://github.com/minetest/minetest/pull/11443/files
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
                    died(dead_player, pos, msg_part or "died")
                else
                    chat_send_player(player:get_player_name()
                        , dead_player_name .. " " .. (msg_part or "died")
                        )
                end
            end
        end
    end)

--[[ minetest.conf: chat_message_format = @timestamp @name: @message

    minetest.register_on_chat_message(function(name, message)
        if name and message then
           minetest.chat_send_all(os.date("%X") .. " " .. name .. ": " .. message)
           return true
        end
    end)
--]]

    minetest.register_on_joinplayer(function(player)
        local player_name = player:get_player_name()
        huds[player_name] = hud_init()
        local v = minetest.get_version()
        chat_send_player(player_name
            , "Welcome to " .. v.project .. " " .. (v.hash or v.string)
            .. " uptime: " .. human_s(minetest.get_server_uptime())
            .. " game day: " .. minetest.get_day_count()
            )
        dump("server_status:".. dump(minetest.get_server_status()))

        wp_init(player)
        check_wp_bones(player, player_name)
        update_wp_bones(player, player_name)
        update_wp_bed(player, player_name)
--        player:hud_set_flags({ minimap = true, minimap_radar =  true })
    end)

    minetest.register_on_leaveplayer(function(player)
        huds[player:get_player_name()] = nil
    end)

    local o_func = { bed = update_wp_bed, bones = update_wp_bones }
    local groups =
        {   { prefix = "display_"
            , opts = { "waypoint", "position", "game", "players", "players_long" }
            , suffix = "_info"
            }
        ,   { prefix = "waypoint_", opts = {}, suffix = "" }
        }

    local g = #groups
    for k, _ in pairs(o_func) do
        groups[g].opts[#groups[g].opts +1] = k
    end

    local function config_set(player, group, opt, val)
        for _, v in ipairs(group.opts) do
            if opt == v then
                local key = modname .. ":" .. group.prefix .. opt .. group.suffix
                player:get_meta():set_int(key, val)
                if o_func[opt] then
                    o_func[opt](player)
                end
                return key .. " " .. ((val == 1) and "enabled" or "disabled")
            end
        end
    end

    -- option 'players' excludes 'players_long' and vice versa
    o_func.players_long = function(player)
        if enabled(groups[1].prefix .. "players_long" .. groups[1].suffix, player) then
            config_set(player, groups[1], "players", 0)
        end
    end

    o_func.players = function(player)
        if enabled(groups[1].prefix .. "players" .. groups[1].suffix, player) then
            config_set(player, groups[1], "players_long", 0)
        end
    end

    minetest.register_chatcommand(modname, {
        params = "[ { + | - }{ any | "
            .. table.concat(groups[2].opts, " | ")
            .. " | "
            .. table.concat(groups[1].opts, " | ")
            .. " } ]",
        description = "shows version of " .. modname,
        func = function(player_name, param)
            local text = modname .. " version " .. moreinfo.version
            local player = minetest.get_player_by_name(player_name)

            if not param or param == "" then
                text = text
                    .. " bones_limit: " .. moreinfo.bones_limit
                    .. " public_death_messages: " .. (enabled("public_death_messages") and "true" or "false")

                if player then
                    table.foreach(groups, function(_, group)
                        table.foreach(group.opts, function(_, opt)
                            local bool = enabled(group.prefix .. opt .. group.suffix, player)
                            text = text .. "\n" .. (bool and "+" or "-") .. opt
                        end)
                    end)
                end

                return true, text
            elseif not player then
                return false, "player not set"
            else
                local first, opt = string.sub(param, 1, 1), string.sub(param, 2)
                local val = ((first == "+") and 1) or ((first == "-") and 0) or nil

                if val ~= nil and opt == "any" then
                    local texts = {}
                    table.foreach(groups, function(_, group)
                        table.foreach(group.opts, function(_, opt)
                            texts[#texts +1] = config_set(player, group, opt, val)
                        end)
                    end)
                    return true, table.concat(texts, "\n")
                elseif val ~= nil and opt ~= nil then
                    text = table.foreach(groups, function(_, group)
                        return config_set(player, group, opt, val)
                    end)
                    return (text ~= nil), text or "command error"
                end
            end
            return false, "unknown command"
        end
    })

    minetest.register_globalstep(function(dtime)
        timer = timer + dtime
        if timer < .3 then return end
        timer = 0
        update_game_info()
        update_players_info()

        for _, player in pairs(minetest.get_connected_players()) do
            do_hud(player)
        end
    end)
end
