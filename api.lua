-- signs_lib api, backported from street_signs

local S = signs_lib.gettext

signs_lib.lbm_restore_nodes = {}
signs_lib.old_fenceposts = {}
signs_lib.old_fenceposts_replacement_signs = {}
signs_lib.old_fenceposts_with_signs = {}
signs_lib.allowed_poles = {}

-- Settings used for a standard wood or steel wall sign
signs_lib.standard_lines = 6
signs_lib.standard_hscale = 1
signs_lib.standard_vscale = 1
signs_lib.standard_lspace = 1
signs_lib.standard_fsize = 15
signs_lib.standard_xoffs = 4
signs_lib.standard_yoffs = 2
signs_lib.standard_cpl = 35

signs_lib.standard_wood_groups =  {choppy = 2, flammable = 2, oddly_breakable_by_hand = 3}
signs_lib.standard_steel_groups = {cracky = 2, oddly_breakable_by_hand = 3} 

signs_lib.standard_yaw = {
	0,
	math.pi / -2,
	math.pi,
	math.pi / 2,
}

signs_lib.wallmounted_yaw = {
	nil,
	nil,
	math.pi / -2,
	math.pi / 2,
	0,
	math.pi,
}

signs_lib.fdir_to_back = {
	{  0, -1 },
	{ -1,  0 },
	{  0,  1 },
	{  1,  0 },
}

signs_lib.wall_fdir_to_back = {
	nil,
	nil,
	{  0,  1 },
	{  0, -1 },
	{ -1,  0 },
	{  1,  0 },
}

signs_lib.rotate_facedir = {
	[0] = 1,
	[1] = 6,
	[2] = 3,
	[3] = 0,
	[4] = 2,
	[5] = 6,
	[6] = 4
}

signs_lib.rotate_walldir = {
	[0] = 1,
	[1] = 5,
	[2] = 0,
	[3] = 4,
	[4] = 2,
	[5] = 3
}

-- Initialize character texture cache
local ctexcache = {}

signs_lib.wallmounted_rotate = function(pos, node, user, mode)
	if not signs_lib.can_modify(pos, user) then return false end

	if mode ~= screwdriver.ROTATE_FACE or string.match(node.name, "_onpole") then
		return false
	end

	local newparam2 = signs_lib.rotate_walldir[node.param2] or 0

	minetest.swap_node(pos, { name = node.name, param2 = newparam2 })
	for _, v in ipairs(minetest.get_objects_inside_radius(pos, 0.5)) do
		local e = v:get_luaentity()
		if e and e.name == "signs_lib:text" then
			v:remove()
		end
	end
	signs_lib.update_sign(pos)
	return true
end

signs_lib.facedir_rotate = function(pos, node, user, mode)
	if not signs_lib.can_modify(pos, user) then return false end

	if mode ~= screwdriver.ROTATE_FACE or string.match(node.name, "_onpole") then
		return false
	end

	local newparam2 = signs_lib.rotate_facedir[node.param2] or 0

	minetest.swap_node(pos, { name = node.name, param2 = newparam2 })
	for _, v in ipairs(minetest.get_objects_inside_radius(pos, 0.5)) do
		local e = v:get_luaentity()
		if e and e.name == "signs_lib:text" then
			v:remove()
		end
	end
	signs_lib.update_sign(pos)
	return true
end

local DEFAULT_TEXT_SCALE = {x=10, y=10}

-- infinite stacks

if not minetest.settings:get_bool("creative_mode") then
	signs_lib.expect_infinite_stacks = false
else
	signs_lib.expect_infinite_stacks = true
end

-- CONSTANTS

-- Path to the textures.
local TP = signs_lib.path .. "/textures"
-- Font file formatter
local CHAR_FILE = "%s_%02x.png"
-- Fonts path
local CHAR_PATH = TP .. "/" .. CHAR_FILE

-- Lots of overkill here. KISS advocates, go away, shoo! ;) -- kaeza

local PNG_HDR = string.char(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)

-- check if a file does exist
-- to avoid reopening file after checking again
-- pass TRUE as second argument
local function file_exists(name, return_handle, mode)
	mode = mode or "r";
	local f = io.open(name, mode)
	if f ~= nil then
		if (return_handle) then
			return f
		end
		io.close(f) 
		return true 
	else 
		return false 
	end
end

-- Read the image size from a PNG file.
-- Returns image_w, image_h.
-- Only the LSB is read from each field!
function signs_lib.read_image_size(filename)
	local f = file_exists(filename, true, "rb")
	-- file might not exist (don't crash the game)
	if (not f) then
		return 0, 0
	end
	f:seek("set", 0x0)
	local hdr = f:read(string.len(PNG_HDR))
	if hdr ~= PNG_HDR then
		f:close()
		return
	end
	f:seek("set", 0x13)
	local ws = f:read(1)
	f:seek("set", 0x17)
	local hs = f:read(1)
	f:close()
	return ws:byte(), hs:byte()
end

-- 4 rows, max 80 chars per, plus a bit of fudge to
-- avoid excess trimming (e.g. due to color codes)

local MAX_INPUT_CHARS = 400

-- helper functions to trim sign text input/output

local function trim_input(text)
	return text:sub(1, math.min(MAX_INPUT_CHARS, text:len()))
end

local function build_char_db(font_size)

	local cw = {}

	-- To calculate average char width.
	local total_width = 0
	local char_count = 0

	for c = 32, 255 do
		local w, h = signs_lib.read_image_size(CHAR_PATH:format("signs_lib_font_"..font_size.."px", c))
		if w and h then
			local ch = string.char(c)
			cw[ch] = w
			total_width = total_width + w
			char_count = char_count + 1
		end
	end

	local cbw, cbh = signs_lib.read_image_size(TP.."/signs_lib_color_"..font_size.."px_n.png")
	assert(cbw and cbh, "error reading bg dimensions")
	return cw, cbw, cbh, (total_width / char_count)
end

signs_lib.charwidth15,
signs_lib.colorbgw15,
signs_lib.lineheight15,
signs_lib.avgwidth15 = build_char_db(15)

signs_lib.charwidth31,
signs_lib.colorbgw31,
signs_lib.lineheight31,
signs_lib.avgwidth31 = build_char_db(31)

local sign_groups = {choppy=2, dig_immediate=2}
local fences_with_sign = { }

-- some local helper functions

local function split_lines_and_words(text)
	if not text then return end
	local lines = { }
	for _, line in ipairs(text:split("\n")) do
		table.insert(lines, line:split(" "))
	end
	return lines
end

local math_max = math.max

local function fill_line(x, y, w, c, font_size, colorbgw)
	c = c or "0"
	local tex = { }
	for xx = 0, math.max(0, w), colorbgw do
		table.insert(tex, (":%d,%d=signs_lib_color_"..font_size.."px_%s.png"):format(x + xx, y, c))
	end
	return table.concat(tex)
end

-- make char texture file name
-- if texture file does not exist use fallback texture instead
local function char_tex(font_name, ch)
	if ctexcache[font_name..ch] then
		return ctexcache[font_name..ch], true
	else
		local c = ch:byte()
		local exists, tex = file_exists(CHAR_PATH:format(font_name, c))
		if exists and c ~= 14 then
			tex = CHAR_FILE:format(font_name, c)
		else
			tex = CHAR_FILE:format(font_name, 0x0)
		end
		ctexcache[font_name..ch] = tex
		return tex, exists
	end
end

local function make_line_texture(line, lineno, pos, line_width, line_height, cwidth_tab, font_size, colorbgw)
	local width = 0
	local maxw = 0
	local font_name = "signs_lib_font_"..font_size.."px"

	local words = { }
	local node = minetest.get_node(pos)
	local def = minetest.registered_items[node.name]
	local default_color = def.default_color or 0

	local cur_color = tonumber(default_color, 16)

	-- We check which chars are available here.
	for word_i, word in ipairs(line) do
		local chars = { }
		local ch_offs = 0
		word = string.gsub(word, "%^[12345678abcdefgh]", {
			["^1"] = string.char(0x81),
			["^2"] = string.char(0x82),
			["^3"] = string.char(0x83),
			["^4"] = string.char(0x84),
			["^5"] = string.char(0x85),
			["^6"] = string.char(0x86),
			["^7"] = string.char(0x87),
			["^8"] = string.char(0x88),
			["^a"] = string.char(0x8a),
			["^b"] = string.char(0x8b),
			["^c"] = string.char(0x8c),
			["^d"] = string.char(0x8d),
			["^e"] = string.char(0x8e),
			["^f"] = string.char(0x8f),
			["^g"] = string.char(0x90),
			["^h"] = string.char(0x91)
		})
		local word_l = #word
		local i = 1
		while i <= word_l  do
			local c = word:sub(i, i)
			if c == "#" then
				local cc = tonumber(word:sub(i+1, i+1), 16)
				if cc then
					i = i + 1
					cur_color = cc
				end
			else
				local w = cwidth_tab[c]
				if w then
					width = width + w + 1
					if width >= (line_width - cwidth_tab[" "]) then
						width = 0
					else
						maxw = math_max(width, maxw)
					end
					if #chars < MAX_INPUT_CHARS then
						table.insert(chars, {
							off = ch_offs,
							tex = char_tex(font_name, c),
							col = ("%X"):format(cur_color),
						})
					end
					ch_offs = ch_offs + w
				end
			end
			i = i + 1
		end
		width = width + cwidth_tab[" "] + 1
		maxw = math_max(width, maxw)
		table.insert(words, { chars=chars, w=ch_offs })
	end

	-- Okay, we actually build the "line texture" here.

	local texture = { }

	local start_xpos = math.floor((line_width - maxw) / 2) + def.x_offset

	local xpos = start_xpos
	local ypos = (line_height + def.line_spacing)* lineno + def.y_offset

	cur_color = nil

	for word_i, word in ipairs(words) do
		local xoffs = (xpos - start_xpos)
		if (xoffs > 0) and ((xoffs + word.w) > maxw) then
			table.insert(texture, fill_line(xpos, ypos, maxw, "n", font_size, colorbgw))
			xpos = start_xpos
			ypos = ypos + line_height + def.line_spacing
			lineno = lineno + 1
			if lineno >= def.number_of_lines then break end
			table.insert(texture, fill_line(xpos, ypos, maxw, cur_color, font_size, colorbgw))
		end
		for ch_i, ch in ipairs(word.chars) do
			if ch.col ~= cur_color then
				cur_color = ch.col
				table.insert(texture, fill_line(xpos + ch.off, ypos, maxw, cur_color, font_size, colorbgw))
			end
			table.insert(texture, (":%d,%d=%s"):format(xpos + ch.off, ypos, ch.tex))
		end
		table.insert(
			texture, 
			(":%d,%d="):format(xpos + word.w, ypos) .. char_tex(font_name, " ")
		)
		xpos = xpos + word.w + cwidth_tab[" "]
		if xpos >= (line_width + cwidth_tab[" "]) then break end
	end

	table.insert(texture, fill_line(xpos, ypos, maxw, "n", font_size, colorbgw))
	table.insert(texture, fill_line(start_xpos, ypos + line_height, maxw, "n", font_size, colorbgw))

	return table.concat(texture), lineno
end

local function make_sign_texture(lines, pos)
	local node = minetest.get_node(pos)
	local def = minetest.registered_items[node.name]

	local font_size
	local line_width
	local line_height
	local char_width
	local colorbgw

	if def.font_size and def.font_size == 31 then
		font_size = 31
		line_width = math.floor(signs_lib.avgwidth31 * def.chars_per_line) * def.horiz_scaling
		line_height = signs_lib.lineheight31
		char_width = signs_lib.charwidth31
		colorbgw = signs_lib.colorbgw31
	else
		font_size = 15
		line_width = math.floor(signs_lib.avgwidth15 * def.chars_per_line) * def.horiz_scaling
		line_height = signs_lib.lineheight15
		char_width = signs_lib.charwidth15
		colorbgw = signs_lib.colorbgw15
	end

	local texture = { ("[combine:%dx%d"):format(line_width, (line_height + def.line_spacing) * def.number_of_lines * def.vert_scaling) }

	local lineno = 0
	for i = 1, #lines do
		if lineno >= def.number_of_lines then break end
		local linetex, ln = make_line_texture(lines[i], lineno, pos, line_width, line_height, char_width, font_size, colorbgw)
		table.insert(texture, linetex)
		lineno = ln + 1
	end
	table.insert(texture, "^[makealpha:0,0,0")
	return table.concat(texture, "")
end

local function set_obj_text(obj, text, x, pos)
	local split = split_lines_and_words
	local text_ansi = Utf8ToAnsi(text)
	local n = minetest.registered_nodes[minetest.get_node(pos).name]
	local text_scale = (n and n.text_scale) or DEFAULT_TEXT_SCALE
	local texture = make_sign_texture(split(text_ansi), pos)
	obj:set_properties({
		textures={texture},
		visual_size = text_scale,
	})
end

signs_lib.construct_sign = function(pos)
	local meta = minetest.get_meta(pos)
	meta:set_string(
		"formspec",
		"size[6,4]"..
		"textarea[0,-0.3;6.5,3;text;;${text}]"..
		"button_exit[2,3.4;2,1;ok;"..S("Write").."]"..
		"background[-0.5,-0.5;7,5;signs_lib_sign_bg.jpg]")
	local i = meta:get_string("infotext")
	if i == "" then -- it wasn't even set, so set it.
		meta:set_string("infotext", "")
	end
end

function signs_lib.destruct_sign(pos)
	local objects = minetest.get_objects_inside_radius(pos, 0.5)
	for _, v in ipairs(objects) do
		local e = v:get_luaentity()
		if e and e.name == "signs_lib:text" then
			v:remove()
		end
	end
end

local function make_infotext(text)
	text = trim_input(text)
	local lines = split_lines_and_words(text) or {}
	local lines2 = { }
	for _, line in ipairs(lines) do
		table.insert(lines2, (table.concat(line, " "):gsub("#[0-9a-fA-F]", ""):gsub("##", "#")))
	end
	return table.concat(lines2, "\n")
end

function signs_lib.update_sign(pos, fields)
	local meta = minetest.get_meta(pos)

	local text = fields and fields.text or meta:get_string("text")
	text = trim_input(text)

	local owner = meta:get_string("owner")
	ownstr = ""
	if owner ~= "" then ownstr = S("Locked sign, owned by @1\n", owner) end

	meta:set_string("text", text)
	meta:set_string("infotext", ownstr..make_infotext(text).." ")

	local objects = minetest.get_objects_inside_radius(pos, 0.5)
	local found
	for _, v in ipairs(objects) do
		local e = v:get_luaentity()
		if e and e.name == "signs_lib:text" then
			if found then
				v:remove()
			else
				set_obj_text(v, text, nil, pos)
				found = true
			end
		end
	end
	if found then
		return
	end

	-- if there is no entity
	local signnode = minetest.get_node(pos)
	local signname = signnode.name
	local def = minetest.registered_items[signname]
	if not def.entity_info or not def.entity_info.yaw[signnode.param2 + 1] then return end
	local obj = minetest.add_entity(pos, "signs_lib:text")

	obj:setyaw(def.entity_info.yaw[signnode.param2 + 1])
	obj:set_properties({
		mesh = def.entity_info.mesh,
	})
end

function signs_lib.receive_fields(pos, formname, fields, sender)
	if fields and fields.text and fields.ok and signs_lib.can_modify(pos, sender) then
		minetest.log("action", S("@1 wrote \"@2\" to sign at @3",
			(sender:get_player_name() or ""),
			fields.text:gsub('\\', '\\\\'):gsub("\n", "\\n"),
			minetest.pos_to_string(pos)
		))
		signs_lib.update_sign(pos, fields)
	end
end

function signs_lib.can_modify(pos, player)
	local meta = minetest.get_meta(pos)
	local owner = meta:get_string("owner")
	local playername = player:get_player_name()

	if minetest.is_protected(pos, playername) then 
		minetest.record_protection_violation(pos, playername)
		return false
	end

	if owner == ""
	  or playername == owner
	  or (minetest.check_player_privs(playername, {sign_editor=true}))
	  or (playername == minetest.settings:get("name")) then
		return true
	end
	minetest.record_protection_violation(pos, playername)
	return false
end

local signs_text_on_activate = function(self)
	local pos = self.object:getpos()
	local meta = minetest.get_meta(pos)
	local signnode = minetest.get_node(pos)
	local signname = signnode.name
	local def = minetest.registered_items[signname]
	local text = meta:get_string("text")
	if text and def and def.entity_info then
		text = trim_input(text)
		set_obj_text(self.object, text, nil, pos)
		self.object:set_properties({
			mesh = def.entity_info.mesh,
		})
	end
end

minetest.register_entity("signs_lib:text", {
	collisionbox = { 0, 0, 0, 0, 0, 0 },
	visual = "mesh",
	mesh = "signs_lib_standard_wall_sign_entity.obj",
	textures = {},
	on_activate = signs_text_on_activate,
})

-- make selection boxes
-- sizex/sizey specified in inches because that's what MUTCD uses.

function signs_lib.make_selection_boxes(sizex, sizey, onpole, xoffs, yoffs, zoffs, fdir)

	local tx = (sizex * 0.0254 ) / 2
	local ty = (sizey * 0.0254 ) / 2
	local xo = xoffs and xoffs * 0.0254 or 0
	local yo = yoffs and yoffs * 0.0254 or 0
	local zo = zoffs and zoffs * 0.0254 or 0

	if onpole == "_onpole" then
		if not fdir then
			return {
				type = "wallmounted",
				wall_side =   { -0.5 - 0.3125 + zo, -ty + yo, -tx + xo, -0.4375 - 0.3125 + zo, ty + yo , tx + xo },
				wall_top =    {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
				wall_bottom = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
			}
		else
			return {
				type = "fixed",
				fixed = { -tx + xo, -ty + yo, 0.5 + 0.3125 + zo, tx + xo, ty + yo, 0.4375 + 0.3125 + zo }
			}
		end
	else
		if not fdir then
			return {
				type = "wallmounted",
				wall_side =   { -0.5 + zo, -ty + yo, -tx + xo, -0.4375 + zo, ty + yo, tx + xo },
				wall_top =    { -tx - xo, 0.5 + zo, -ty + yo, tx - xo, 0.4375 + zo, ty + yo},
				wall_bottom = { -tx - xo, -0.5 + zo, -ty + yo, tx - xo, -0.4375 + zo, ty + yo }
			}
		else
			return {
				type = "fixed",
				fixed = { -tx + xo, -ty + yo, 0.5 + zo, tx + xo, ty + yo, 0.4375 + zo}
			}
		end
	end
end

function signs_lib.check_for_pole(pos, pointed_thing)
	local ppos = minetest.get_pointed_thing_position(pointed_thing)
	local pnode = minetest.get_node(ppos)
	local pdef = minetest.registered_items[pnode.name]

	print(dump(pos))
	print(dump(ppos))

	if (signs_lib.allowed_poles[pnode.name]
		  or (pdef and pdef.drawtype == "fencelike")
		  or string.find(pnode.name, "default:fence_")
		  or string.find(pnode.name, "_post")
		  or string.find(pnode.name, "fencepost")
		  or (pnode.name == "streets:bigpole" and pnode.param2 < 4)
		  or (pnode.name == "streets:bigpole" and pnode.param2 > 19 and pnode.param2 < 24)
		)
	  and
		(pos.x ~= ppos.x or pos.z ~= ppos.z) then
		print("signs_lib.check_for_pole returned true")
		return true
	end
end

function signs_lib.after_place_node(pos, placer, itemstack, pointed_thing, locked)
	local ppos = minetest.get_pointed_thing_position(pointed_thing)
	local pnode = minetest.get_node(ppos)
	local pdef = minetest.registered_items[pnode.name]
	local playername = placer:get_player_name()

	if signs_lib.check_for_pole(pos, pointed_thing) then
		local node = minetest.get_node(pos)
		minetest.swap_node(pos, {name = itemstack:get_name().."_onpole", param2 = node.param2})
	end
	if locked then
		local meta = minetest.get_meta(pos)
		meta:set_string("owner", playername)
		meta:set_string("infotext", S("Locked sign, owned by @1\n", playername))
	end
end

function signs_lib.register_fence_with_sign()
	minetest.log("warning", "[signs_lib] ".."Attempt to call no longer used function signs_lib.register_fence_with_sign()")
end

-- restore signs' text after /clearobjects and the like, the next time
-- a block is reloaded by the server.

minetest.register_lbm({
	nodenames = signs_lib.lbm_restore_nodes,
	name = "signs_lib:restore_sign_text",
	label = "Restore sign text",
	run_at_every_load = true,
	action = function(pos, node)
		signs_lib.update_sign(pos,nil,nil,node)
	end
})

-- Convert old signs on fenceposts into signs on.. um.. fence posts :P

minetest.register_lbm({
	nodenames = signs_lib.old_fenceposts_with_signs,
	name = "signs_lib:fix_fencepost_signs",
	label = "Change single-node signs on fences into normal",
	run_at_every_load = true,
	action = function(pos, node)

		local fdir = node.param2 % 8
		local signpos = {
			x = pos.x + signs_lib.fdir_to_back[fdir+1][1],
			y = pos.y,
			z = pos.z + signs_lib.fdir_to_back[fdir+1][2]
		}

		if minetest.get_node(signpos).name == "air" then
			local new_wmdir = minetest.dir_to_wallmounted(minetest.facedir_to_dir(fdir))
			local oldfence =  signs_lib.old_fenceposts[node.name]
			local newsign =   signs_lib.old_fenceposts_replacement_signs[node.name]

			for _, v in ipairs(minetest.get_objects_inside_radius(pos, 0.5)) do
				local e = v:get_luaentity()
				if e and e.name == "signs_lib:text" then
					v:remove()
				end
			end

			local oldmeta = minetest.get_meta(pos):to_table()
			minetest.set_node(pos, {name = oldfence})
			minetest.set_node(signpos, { name = newsign, param2 = new_wmdir })
			local newmeta = minetest.get_meta(signpos)
			newmeta:from_table(oldmeta)
			signs_lib.update_sign(signpos)
		end
	end
})
