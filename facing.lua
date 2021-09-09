-- https://forum.minetest.net/viewtopic.php?t=26462
function moreinfo.facing(digger, objects, liquids)
        -- calculation of eye position ripped from builtins 'pointed_thing_to_face_pos'
	local digger_pos = digger:get_pos()
	local eye_height = digger:get_properties().eye_height
	local eye_offset = digger:get_eye_offset()
	digger_pos.y = digger_pos.y + eye_height
	digger_pos = vector.add(digger_pos, eye_offset)

	-- get wielded item range 5 is engine default
	-- order tool/item range >> hand_range >> fallback 5
	local tool_range = digger:get_wielded_item():get_definition().range or nil
	local hand_range
        for key, val in pairs(minetest.registered_items) do
                if key == "" then
                        hand_range = val.range or nil
                end
        end
	local wield_range = tool_range or hand_range or 5

	-- determine ray end position
	local look_dir = digger:get_look_dir()
	look_dir = vector.multiply(look_dir, wield_range)
	local end_pos = vector.add(look_dir, digger_pos)

	-- get pointed_thing
	local ray = minetest.raycast(digger_pos, end_pos, objects or false, liquids or false)
--        if 1 then return ray end
	local ray_pt = ray:next()

        return ray_pt or nil
--[[
        if 1 then return ray_pt.under end

	local normal = ray_pt.intersection_normal
        -- minetest.debug("face_normal: \n"..dump(normal))
        return normal
--]]
end
