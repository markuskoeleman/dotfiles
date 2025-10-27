-- vim.keymap.set("t", "<esc><esc>", "c-\\><c-n>")

local state = {
	floating = {
		buf = -1,
		win = -1,
	},
	terminal = {
		mode = {
			insert = false,
		},
	},
}

local max_height = vim.api.nvim_win_get_height(0)
local max_width = vim.api.nvim_win_get_width(0)

local width = math.floor(max_width * 0.8)
local height = math.floor(max_width * 0.8)

local col = math.floor((vim.o.columns - width) / 2)
local row = math.floor((vim.o.lines - height) / 2)

local win_config = {
	relative = "editor",
	height = height,
	width = width,
	col = col,
	row = row,
	style = "minimal",
	border = "rounded",
}

local function create_terminal(opts)
	opts = opts or {}
	local buf = nil
	if vim.api.nvim_buf_is_valid(opts.buf) then
		buf = opts.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	local win = vim.api.nvim_open_win(buf, true, win_config)
	return { buf = buf, win = win }
end

local function toggle_term()
	-- print(state.terminal.mode.insert)
	if not vim.api.nvim_win_is_valid(state.floating.win) then
		state.floating = create_terminal({ buf = state.floating.buf })
		if vim.bo[state.floating.buf].buftype ~= "terminal" then
			vim.cmd.term()
			if state.terminal.mode.insert then
				vim.cmd.startinsert()
			end
		end
	else
		if vim.api.nvim_get_mode() == "t" then
			state.terminal.mode.insert = true
		else
			state.terminal.mode.insert = false
		end
		vim.api.nvim_win_hide(state.floating.win)
	end
end

vim.api.nvim_create_user_command("Floaterm", toggle_term, {})
vim.keymap.set({ "t", "n" }, "\\", toggle_term)
