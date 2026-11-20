-- A small, literal-text jump picker inspired by flash.nvim and nvim-jump.
-- Search is limited to the visible lines of the current window.

local M = {}

local api = vim.api
local fn = vim.fn
local ns = api.nvim_create_namespace("personal_jump")

local config = {
	labels = "asdfghjklqwertyuiopzxcvbnm;",
	match_hl = "Search",
	label_hl = "JumpLabel",
}

-- Initialize labels once when the module is loaded.
local labels = {}
local seen = {}

for i = 1, #config.labels do
	local label = config.labels:sub(i, i)

	if not seen[label] then
		labels[#labels + 1] = label
		seen[label] = true
	end
end

local running = false

local keys = {
	esc = vim.keycode("<Esc>"),
	cr = vim.keycode("<CR>"),
	bs = vim.keycode("<BS>"),
	del = vim.keycode("<Del>"),
	ctrl_h = vim.keycode("<C-h>"),
	ctrl_u = vim.keycode("<C-u>"),
	ctrl_c = vim.keycode("<C-c>"),
}

local function case_insensitive(query)
	if not vim.o.ignorecase then
		return false
	end

	return not (vim.o.smartcase and fn.tolower(query) ~= query)
end

local function get_visible_lines(win, buf)
	local info = fn.getwininfo(win)[1]
	if not info then
		return {}, {}, 0
	end

	local top = info.topline
	local bottom = info.botline
	local lines = api.nvim_buf_get_lines(buf, top - 1, bottom, false)
	local lower_lines = {}

	-- Do this once per jump, not once per typed character.
	for i, line in ipairs(lines) do
		lower_lines[i] = fn.tolower(line)
	end

	return lines, lower_lines, top - 1
end

local function find_matches(lines, lower_lines, query, insensitive, start_row, columns, cursor_pos_num)
	local needle = insensitive and fn.tolower(query) or query
	local matches = {}
	local source_lines = insensitive and lower_lines or lines

	for row, line in ipairs(source_lines) do
		local from = 1

		while from <= #line do
			local first, last = line:find(needle, from, true)
			if not first then
				break
			end

			local row0 = row - 1
			local col0 = first - 1

			matches[#matches + 1] = {
				row = row0,
				col = col0,
				end_col = last,
				distance = math.abs(
					(start_row + row0) * columns + col0 - cursor_pos_num
				),
			}

			-- Advance one byte to retain overlapping matches.
			from = first + 1
		end
	end

	table.sort(matches, function(a, b)
		if a.distance ~= b.distance then
			return a.distance < b.distance
		end

		-- top to bottom ordering for equal distances
		if a.row ~= b.row then
			return a.row < b.row
		end

		-- if on the same row sort left to right
		return a.col < b.col
	end)

	return matches
end

local function extend_matches(previous, lines, lower_lines, query, insensitive)
	local needle = insensitive and fn.tolower(query) or query
	local source_lines = insensitive and lower_lines or lines
	local matches = {}

	-- Every match for the longer literal query must begin at a match
	-- position from the previous query. Filtering is cheaper than rescanning.
	for _, match in ipairs(previous) do
		local line = source_lines[match.row + 1]
		local first = match.col + 1
		local last = first + #needle - 1

		if line:sub(first, last) == needle then
			matches[#matches + 1] = {
				row = match.row,
				col = match.col,
				end_col = last,
				distance = match.distance,
			}
		end
	end

	return matches
end

local function assign_labels(matches, lines, lower_lines, insensitive, used_labels)
	local forbidden = {}
	local source_lines = insensitive and lower_lines or lines

	-- A key cannot be a label if it could extend the current search at any
	-- match. This is the important Flash-style ambiguity rule.
	for _, match in ipairs(matches) do
		local line = source_lines[match.row + 1]
		local next_char = line:sub(match.end_col + 1, match.end_col + 1)
		if next_char ~= "" then
			forbidden[next_char] = true
		end
	end

	local available = {}
	for _, label in ipairs(labels) do
		if not forbidden[label] then
			available[#available + 1] = label
		end
	end

	for _, match in ipairs(matches) do
		match.label = nil
	end

	local active = {}
	local available_set = {}
	for _, label in ipairs(available) do
		available_set[label] = true
	end

	-- Reuse labels for positions that remain in the candidate set, as Flash
	-- does. This avoids labels jumping around while the query is extended.
	for _, match in ipairs(matches) do
		local key = match.row .. ":" .. match.col
		local label = used_labels[key]
		if label and available_set[label] then
			match.label = label
			active[label] = match
			available_set[label] = nil
		end
	end

	-- Give unused labels to the remaining matches in proximity order.
	local next_label = 1
	for _, match in ipairs(matches) do
		if not match.label then
			while available[next_label] and not available_set[available[next_label]] do
				next_label = next_label + 1
			end
			local label = available[next_label]
			if not label then
				break
			end
			match.label = label
			active[label] = match
			used_labels[match.row .. ":" .. match.col] = label
			available_set[label] = nil
			next_label = next_label + 1
		end
	end

	return active
end

local function render(buf, lines, lower_lines, start_row, state, used_labels)
	api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local current = state[#state]
	if current.query == "" then
		api.nvim_echo({ { "/", "IncSearch" } }, false, {})
		vim.cmd("redraw")
		return {}
	end

	local insensitive = current.insensitive
	local active = assign_labels(current.matches, lines, lower_lines, insensitive, used_labels)

	for _, match in ipairs(current.matches) do
		api.nvim_buf_set_extmark(buf, ns, start_row + match.row, match.col, {
			end_row = start_row + match.row,
			end_col = match.end_col,
			hl_group = config.match_hl,
			priority = 200,
		})

		if match.label then
			local line = lines[match.row + 1]
			api.nvim_buf_set_extmark(buf, ns, start_row + match.row, match.end_col, {
				virt_text = { { match.label, config.label_hl } },
				virt_text_pos = match.end_col >= #line and "eol" or "overlay",
				priority = 201,
			})
		end
	end

	api.nvim_echo({ { "/" .. current.query, "IncSearch" } }, false, {})
	vim.cmd("redraw")
	return active
end

local function is_printable_input(char)
	if char == "" then
		return false
	end

	local first = char:byte(1)
	-- getcharstr() encodes special keys with K_SPECIAL (0x80). Ignore those,
	-- along with control characters that are not handled explicitly.
	return first ~= 0x80 and first >= 32 and first ~= 127
end

function M.start()
	if running then
		return
	end

	local win = api.nvim_get_current_win()
	local buf = api.nvim_win_get_buf(win)
	if not api.nvim_buf_is_valid(buf) then
		return
	end

	local lines, lower_lines, start_row = get_visible_lines(win, buf)
	if #lines == 0 then
		return
	end

	local cursor = api.nvim_win_get_cursor(win)
	local columns = vim.o.columns
	local cursor_pos_num = (cursor[1] - 1) * columns + cursor[2]

	running = true

	-- Each entry caches the matches for one query prefix. Backspace is then
	-- constant-time (just pop the most recent prefix) instead of rescanning.
	local state = {
		{
			query = "",
			matches = {},
			insensitive = true,
		},
	}
	local target
	local used_labels = {}
	local ok, err = xpcall(function()
		local active = render(buf, lines, lower_lines, start_row, state, used_labels)

		while true do
			local char = fn.getcharstr(-1, { cursor = "keep" })
			if char == "" or char == keys.esc or char == "\27" or char == keys.ctrl_c or char == "\3" then
				break
			elseif char == keys.cr or char == "\r" or char == "\n" then
				target = state[#state].matches[1]
				break
			elseif char == keys.bs or char == keys.del or char == keys.ctrl_h or char == "\8" or char == "\127" then
				if #state > 1 then
					table.remove(state)
					active = render(buf, lines, lower_lines, start_row, state, used_labels)
				end
			elseif char == keys.ctrl_u or char == "\21" then
				state = { state[1] } -- return to initial state
				active = render(buf, lines, lower_lines, start_row, state, used_labels)
			elseif active[char] then
				target = active[char]
				break
			elseif is_printable_input(char) then
				local previous = state[#state]
				local query = previous.query .. char
				local insensitive = case_insensitive(query)

				local matches
				if previous.query == "" then
					matches = find_matches(
						lines,
						lower_lines,
						query,
						insensitive,
						start_row,
						columns,
						cursor_pos_num
					)
				else
					matches = extend_matches(previous.matches, lines, lower_lines, query, insensitive)
				end

				state[#state + 1] = {
					query = query,
					matches = matches,
					insensitive = insensitive,
				}
				active = render(buf, lines, lower_lines, start_row, state, used_labels)
			end
		end
	end, debug.traceback)

	pcall(function()
		if api.nvim_buf_is_valid(buf) then
			api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		end

		api.nvim_echo({ { "", "Normal" } }, false, {})
		vim.cmd.redraw()
	end)
	running = false

	if target and api.nvim_win_is_valid(win) and api.nvim_buf_is_valid(buf) then
		-- Match nvim-jump's simple jumplist behavior.
		vim.cmd("normal! m'")
		api.nvim_win_set_cursor(win, { start_row + target.row + 1, target.col })
	elseif not ok then
		local message = tostring(err)
		if not message:lower():find("interrupt", 1, true) then
			vim.notify(message, vim.log.levels.ERROR, { title = "jump.lua" })
		end
	end
end

return M
