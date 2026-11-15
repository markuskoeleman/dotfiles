local M = {}

-- fullscreen terminal
local term_state = {
	floating = {
		buf = -1,
		win = -1,
	},
	job_id = 0,
	typst = {
		is_watching = false,
	},
}
local function create_terminal(state)
	state = state or {}
	local buf = nil
	if vim.api.nvim_buf_is_valid(state.buf) then
		buf = state.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	local win = vim.api.nvim_open_win(buf --[[@as integer]], true, {
		relative = "editor",
		width = vim.api.nvim_win_get_width(0),
		height = vim.api.nvim_win_get_height(0),
		style = "minimal",
		border = "none",
		row = 0,
		col = 0,
	})
	return { buf = buf, win = win }
end

function M.toggle_term()
	if not vim.api.nvim_win_is_valid(term_state.floating.win) then
		term_state.floating = create_terminal({ buf = term_state.floating.buf })
		if vim.bo[term_state.floating.buf].buftype ~= "terminal" then
			vim.cmd.term()
			term_state.job_id = vim.bo.channel
		end
		vim.cmd.startinsert()
	else
		vim.api.nvim_win_hide(term_state.floating.win)
	end
end

function M.typst_open_file()
	local filepath = vim.api.nvim_buf_get_name(0)
	local filename = vim.fs.basename(filepath)
	local dir = vim.fs.dirname(filepath)
	local dirname = vim.fs.basename(dir)
	local output = dir .. '/' .. dirname .. '-' .. string.gsub(filename, ".typ", ".pdf")

	if not string.find(filename, ".typ") then
		print("Failed to open file, File is not a typst file")
		return
	end
	vim.ui.open(output)
end

function M.typst_watch_file()
	--  check and kill the old job first if it exists
	if term_state.typst.is_watching then
		-- Kill the actual OS process
		if term_state.job_id > 0 then
			vim.fn.jobstop(term_state.job_id)
			term_state.job_id = 0
		end
		-- Clean up the buffer
		if vim.api.nvim_buf_is_valid(term_state.floating.buf) then
			vim.api.nvim_buf_delete(term_state.floating.buf, { force = true })
		end
		term_state.typst.is_watching = false
	end
	local filepath = vim.api.nvim_buf_get_name(0)
	local filename = vim.fs.basename(filepath)
	local dir = vim.fs.dirname(filepath)
	local dirname = vim.fs.basename(dir)
	local output = dir .. '/' .. dirname .. '-' .. string.gsub(filename, ".typ", ".pdf")

	if not string.find(filename, ".typ") then
		print("Unable to watch file, File is not a typst file")
		return
	end
	term_state.floating = create_terminal({ buf = term_state.floating.buf })
	if vim.bo[term_state.floating.buf].buftype ~= "terminal" then
		vim.cmd.term()
		term_state.job_id = vim.bo.channel
	end
	local assignment = vim.fn.fnamemodify(filepath, ":t:r")
	local cmd = ("typst watch --input %s --input %s %s %s\r\n"):format(
		vim.fn.shellescape("assignment=" .. assignment),
		vim.fn.shellescape("course=" .. dirname),
		vim.fn.shellescape(filepath),
		vim.fn.shellescape(output)
	)
	vim.fn.chansend(term_state.job_id, { cmd })
	term_state.typst.is_watching = true
end

return M
