local M = {}

-- handy todo togle add -> - [] to the line or toggle - [x]
function M.checkbox_line(line)
	if line:find('%[ %]') then
		return (line:gsub('%[ %]', '[x]', 1))
	elseif line:find('%[x%]') or line:find('%[>%]') then
		return line
	elseif line:match('%S') then
		local indent, content = line:match('^(%s*)(.*)$')
		return indent .. '- [ ] ' .. content
	end
	return line
end

-- Normal mode: Toggle current line
vim.keymap.set('n', '<leader>x', function()
	local line = vim.api.nvim_get_current_line()
	vim.api.nvim_set_current_line(M.checkbox_line(line))
end, { desc = "Toggle checkbox" })

-- Visual mode: Toggle all highlighted lines
vim.keymap.set('v', '<leader>x', function()
	local start_line = vim.fn.line('v')
	local end_line = vim.fn.line('.')
	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	for i, line in ipairs(lines) do
		lines[i] = M.checkbox_line(line)
	end
	vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
end, { desc = "Toggle checkboxes on selection" })

-- Carry uncompleted tasks from previous days over to current day
local scratch_dir = vim.fn.expand("~/.cache/todoscratch")
local days_in_past = 14

function M.carry_tasks()
	local today = os.date("%Y-%m-%d")
	local today_path = scratch_dir .. "/" .. today .. ".md"

	if vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":p")
		~= vim.fn.fnamemodify(today_path, ":p") then
		vim.notify("Open today's scratchpad first.", vim.log.levels.WARN)
		return
	end

	local groups, order, sources = {}, {}, {}
	local now = os.date("*t")
	local count = 0

	-- Scan the previous day window, oldest first.
	for d = days_in_past, 1, -1 do
		local date = os.date("%Y-%m-%d", os.time({
			year = now.year,
			month = now.month,
			day = now.day - d,
			hour = 12,
		}))
		local path = scratch_dir .. "/" .. date .. ".md"

		if vim.fn.filereadable(path) == 1 then
			local buf = vim.fn.bufnr(path)
			local loaded = buf ~= -1 and vim.api.nvim_buf_is_loaded(buf)
			local lines = loaded
				and vim.api.nvim_buf_get_lines(buf, 0, -1, false)
				or vim.fn.readfile(path)

			local heading = "# Loose tasks"
			local heading_has_tasks = false
			local changed = false

			for i, line in ipairs(lines) do
				local found_heading = line:match("^%s*(#+%s+.+)$")
				local is_task = line:match("^%s*%- %[[^%]]%]")
				local is_unfinished = line:match("^%s*%- %[%s%]")

				if found_heading then
					heading = found_heading
					heading_has_tasks = false
				elseif line:match("^%s*$") then
					if heading_has_tasks then
						heading = "# Loose tasks"
						heading_has_tasks = false
					end
				elseif is_task then
					heading_has_tasks = true

					if is_unfinished then
						if loaded and vim.bo[buf].modified then
							vim.notify("Save the old note first: " .. path,
								vim.log.levels.WARN)
							return
						end

						if not groups[heading] then
							groups[heading] = {}
							order[#order + 1] = heading
						end

						groups[heading][#groups[heading] + 1] = line
						lines[i] = line:gsub("%[ %]", "[>]", 1)
							:gsub("%s+$", "") .. " (carried to " .. today .. ")"

						count = count + 1
						changed = true
					end
				end
			end

			if changed then
				sources[#sources + 1] = {
					path = path,
					lines = lines,
					buf = loaded and buf or nil,
				}
			end
		end
	end

	if count == 0 then
		vim.notify("No unfinished tasks found.", vim.log.levels.INFO)
		return
	end

	-- Build today's section.
	local block = { "# Carried over from previous days", "" }

	for _, heading in ipairs(order) do
		block[#block + 1] = "#" .. heading -- prefix #
		vim.list_extend(block, groups[heading])
		block[#block + 1] = ""
	end

	local original = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local was_modified = vim.bo.modified
	local destination = vim.deepcopy(original)

	if #destination == 1 and destination[1] == "" then
		destination = {}
	elseif #destination > 0 and destination[#destination] ~= "" then
		destination[#destination + 1] = ""
	end

	vim.list_extend(destination, block)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, destination)

	-- Save today's note before marking the old tasks.
	local ok, err = pcall(function()
		vim.cmd("write")
	end)

	if not ok then
		vim.api.nvim_buf_set_lines(0, 0, -1, false, original)
		vim.bo.modified = was_modified
		vim.notify("Could not save today's note: " .. tostring(err),
			vim.log.levels.ERROR)
		return
	end

	-- Mark the originals as carried.
	for _, source in ipairs(sources) do
		if vim.fn.writefile(source.lines, source.path) ~= 0 then
			vim.notify("Could not update " .. source.path,
				vim.log.levels.ERROR)
		elseif source.buf then
			vim.api.nvim_buf_set_lines(
				source.buf, 0, -1, false, source.lines
			)
			vim.bo[source.buf].modified = false
		end
	end

	vim.notify(("Carried %d tasks from %d notes."):format(
		count, #sources
	), vim.log.levels.INFO)
end

return M
