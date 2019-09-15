-- Definitions for standard minetest_game wooden and steel wall signs

signs_lib.register_sign("default:sign_wall_wood", {
	description = "Wooden wall sign",
	inventory_image = "signs_lib_sign_wall_wooden_inv.png",
	tiles = {
		"signs_lib_sign_wall_wooden.png",
		"signs_lib_sign_wall_wooden_edges.png",
	},
	entity_info = "standard"
})

signs_lib.register_sign("default:sign_wall_steel", {
	description = "Steel wall sign",
	inventory_image = "signs_lib_sign_wall_steel_inv.png",
	tiles = {
		"signs_lib_sign_wall_steel.png",
		"signs_lib_sign_wall_steel_edges.png",
	},
	groups = signs_lib.standard_steel_groups,
	sounds = signs_lib.standard_steel_sign_sounds,
	locked = true,
	entity_info = "standard"
})

-- insert the old wood sign-on-fencepost into signs_lib's conversion LBM

table.insert(signs_lib.old_fenceposts_with_signs, "signs:sign_post")
signs_lib.old_fenceposts["signs:sign_post"] = "default:fence_wood"
signs_lib.old_fenceposts_replacement_signs["signs:sign_post"] = "default:sign_wall_wood_onpole"
