-- Definitions for standard minetest_game wooden and steel wall signs

for _, onpole in ipairs({"", "_onpole"}) do

	local nci = nil
	local on_rotate = signs_lib.wallmounted_rotate
	local pole_mount_tex = nil

	if onpole == "_onpole" then
		nci = 1
		on_rotate = nil
		pole_mount_tex = "signs_lib_pole_mount.png" -- the metal straps on back, if needed
	end

	local wood_groups =  table.copy(signs_lib.standard_wood_groups)
	wood_groups.not_in_creative_inventory = nci
	local steel_groups =  table.copy(signs_lib.standard_steel_groups)
	steel_groups.not_in_creative_inventory = nci

	cbox = signs_lib.make_selection_boxes(35, 25, onpole)

	minetest.register_node(":default:sign_wall_wood"..onpole, {
		description = "Wooden wall sign",
		paramtype = "light",
		sunlight_propagates = true,
		paramtype2 = "wallmounted",
		drawtype = "mesh",
		node_box = cbox,
		selection_box = cbox,
		mesh = "signs_lib_standard_wall_sign"..onpole..".obj",
		tiles = {
			"signs_lib_sign_wall_wooden.png",
			"signs_lib_sign_wall_wooden_edges.png",
			pole_mount_tex
		},
		inventory_image = "signs_lib_sign_wall_wooden_inv.png",
		wield_image = "signs_lib_sign_wall_wooden_inv.png",
		groups = wood_groups,
		default_color = "0",
		on_rightclick = signs_lib.construct_sign,
		on_construct = signs_lib.construct_sign,
		on_destruct = signs_lib.destruct_sign,
		on_receive_fields = signs_lib.receive_fields,
		on_punch = signs_lib.update_sign,
		on_rotate = signs_lib.wallmounted_rotate,
		number_of_lines = signs_lib.standard_lines,
		horiz_scaling = signs_lib.standard_hscale,
		vert_scaling = signs_lib.standard_vscale,
		line_spacing = signs_lib.standard_lspace,
		font_size = signs_lib.standard_fsize,
		x_offset = signs_lib.standard_xoffs,
		y_offset = signs_lib.standard_yoffs,
		chars_per_line = signs_lib.standard_cpl,
		entity_info = {
			mesh = "signs_lib_standard_wall_sign_entity"..onpole..".obj",
			yaw = signs_lib.wallmounted_yaw
		},
		drop = "default:sign_wall_wood"
	})
	table.insert(signs_lib.lbm_restore_nodes, "default:sign_wall_wood"..onpole)

	minetest.register_node(":default:sign_wall_steel"..onpole, {
		description = "Steel wall sign",
		paramtype = "light",
		sunlight_propagates = true,
		paramtype2 = "wallmounted",
		drawtype = "mesh",
		node_box = cbox,
		selection_box = cbox,
		mesh = "signs_lib_standard_wall_sign"..onpole..".obj",
		tiles = {
			"signs_lib_sign_wall_steel.png",
			"signs_lib_sign_wall_steel_edges.png",
			pole_mount_tex
		},
		inventory_image = "signs_lib_sign_wall_steel_inv.png",
		wield_image = "signs_lib_sign_wall_steel_inv.png",
		groups = wood_groups,
		default_color = "0",
		on_rightclick = signs_lib.construct_sign,
		on_construct = signs_lib.construct_sign,
		on_destruct = signs_lib.destruct_sign,
		after_place_node = function(pos, placer, itemstack, pointed_thing)
			signs_lib.after_place_node(pos, placer, itemstack, pointed_thing, true)
		end,
		on_receive_fields = signs_lib.receive_fields,
		on_punch = signs_lib.update_sign,
		can_dig = signs_lib.can_modify,
		on_rotate = signs_lib.wallmounted_rotate,
		number_of_lines = signs_lib.standard_lines,
		horiz_scaling = signs_lib.standard_hscale,
		vert_scaling = signs_lib.standard_vscale,
		line_spacing = signs_lib.standard_lspace,
		font_size = signs_lib.standard_fsize,
		x_offset = signs_lib.standard_xoffs,
		y_offset = signs_lib.standard_yoffs,
		chars_per_line = signs_lib.standard_cpl,
		entity_info = {
			mesh = "signs_lib_standard_wall_sign_entity"..onpole..".obj",
			yaw = signs_lib.wallmounted_yaw
		},
		drop = "default:sign_wall_steel"
	})
	table.insert(signs_lib.lbm_restore_nodes, "default:sign_wall_steel"..onpole)
end
