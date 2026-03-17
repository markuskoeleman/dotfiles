vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.o.number = true
vim.o.wrap = false
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4

vim.opt.swapfile = false
vim.o.breakindent = true

vim.o.ignorecase = true
vim.o.smartcase = true

vim.o.winborder = "rounded"
vim.o.signcolumn = "yes"
vim.o.cursorline = false
vim.o.scrolloff = 10

vim.o.updatetime = 250
vim.o.timeoutlen = 300

vim.o.splitright = true
vim.o.splitbelow = true

vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

vim.o.statusline = [[ %<%f%m %y%= %-14.(%l-%L %c%V%) %P ]]

local map = vim.keymap.set
-- system clipboard
map({ "n", "v", "x" }, "<leader>y", '"+y')
map({ "n", "v", "x" }, "<leader>p", '"+p')

map("n", "<C-h>", "<C-w><C-h>")
map("n", "<C-l>", "<C-w><C-l>")
map("n", "<C-j>", "<C-w><C-j>")
map("n", "<C-k>", "<C-w><C-k>")

-- quickfix
map("n", "<M-j>", "<cmd>cnext<CR>")
map("n", "<M-k>", "<cmd>cprev<CR>")

-- Clear highlights on search when pressing <Esc> in normal mode
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
-- exit terminal mode
map("t", "<Esc><Esc>", "<C-\\><C-n>")

-- Move selected lines in visual mode
map('x', "J", ":m '>+1<cr>gv=gv")
map('x', "K", ":m '<-2<CR>gv=gv")

vim.pack.add({
	{ src = "https://github.com/vague-theme/vague.nvim" },
	{ src = "https://github.com/neovim/nvim-lspconfig" },
	{ src = 'https://github.com/Saghen/blink.cmp',      version = vim.version.range('*') },
	{ src = "https://github.com/nvim-mini/mini.nvim" },
	{ src = "https://github.com/folke/flash.nvim" },
})
require("mini.icons").setup()
require("mini.pick").setup()
require("mini.ai").setup()
require('mini.extra').setup()
require("mini.files").setup({
	mappings = {
		go_in_plus = "<CR>"
	}
})
require("mini.surround").setup({
	mappings = {
		add = 'gsa', -- Add surrounding in Normal and Visual modes
		delete = 'gsd', -- Delete surrounding
		find = 'gsf', -- Find surrounding (to the right)
		find_left = 'gsF', -- Find surrounding (to the left)
		highlight = 'gsh', -- Highlight surrounding
		replace = 'gsr', -- Replace surrounding

		suffix_last = 'l', -- Suffix to search with "prev" method
		suffix_next = 'n', -- Suffix to search with "next" method
	},
})
require("blink.cmp").setup({
	keymap = { preset = "default" },
	appearance = {
		nerd_font_variant = "mono",
	},
	signature = { enabled = true },
	completion = {
		list = {
			selection = {
				preselect = false, -- Allows me to avoid function placeholder argument snippets
			},
		},
	},
})
require("flash").setup({
	labels = "asdfghjklqwertyuiopzxcvbnm;",
	highlight = {
		backdrop = false,
	},
	label = {
		uppercase = false, -- bit too much cognitive load for me idk
	},
	modes = {
		char = {
			enabled = false,
		},
		search = {
			enabled = false,
		},
	},
})
require("vague").setup({
	transparent = true,
	bold = false,
	italic = false,
})

vim.lsp.config("tinymist", {
	settings = {
		formatterMode = "typstyle", -- enables formatting
		formatterPrintWidth = 100,
		formatterProseWrap = true,
	},
})

map("n", "<leader>tp", function()
	local clients = vim.lsp.get_clients({ name = "tinymist" })
	if #clients > 0 then
		clients[1]:exec_cmd({
			command = "tinymist.startDefaultPreview",
			arguments = { vim.api.nvim_buf_get_name(0) }, -- Pass current file
			title = "Typst Preview",
		})
	else
		print("Tinymist not active")
	end
end, { desc = "Typst Preview" })

vim.lsp.enable({
	"lua_ls",
	"clangd",
	"rust_analyzer",
	"zls",
	"pyright",
	"tinymist",
})

vim.diagnostic.config({
	severity_sort = true,
	float = { border = "rounded", source = "if_many" },
	underline = { severity = vim.diagnostic.severity.ERROR },
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
		},
	},
	virtual_text = { severity = { min = vim.diagnostic.severity.WARN } },
})

vim.cmd("colorscheme vague")

-- disable greying out unsused
vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", {})
-- wanted to make the flash labels a little more visible
vim.api.nvim_set_hl(0, "FlashLabel", { bg = "#CC0066", fg = "#FFFFFF" })

map({ "n", "x", "o" }, "s", require("flash").jump)

-- lsp
map("n", "<leader>q", vim.diagnostic.setqflist)
map("n", "<leader>lf", vim.lsp.buf.format)

-- picking
map("n", "<leader>f", "<cmd>Pick files<CR>")
map("n", "<leader>sh", "<cmd>Pick help<CR>")
map("n", "<leader>sw", "<cmd>Pick grep<CR>")
map("n", "<leader>sg", "<cmd>Pick grep_live<CR>")
map("n", "<leader>sb", "<cmd>Pick buffers<CR>")
map("n", "<leader>sd", "<cmd>Pick diagnostic<CR>")
map("n", "<leader>sm", "<cmd>Pick keymaps<CR>")
map("n", "<leader>sl", function() require("mini.extra").pickers.lsp({ scope = 'document_symbol' }) end)

-- finding files in the neovim config dir
map("n", "<leader>sn", function()
	require("mini.extra").pickers.explorer({ cwd = vim.fn.stdpath("config") })
end)
-- finding files in neovim plugin dir
map("n", "<leader>sp", function()
	require("mini.extra").pickers.explorer({
		cwd = vim.fs.joinpath(vim.fn.stdpath("data"),
			"site", "pack", "core", "opt")
	})
end)

map("n", "<leader>e", require("mini.files").open)

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

	local win = vim.api.nvim_open_win(buf, true, {
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

local function toggle_term()
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

local function typst_open_file()
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

local function typst_watch_file()
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
	local cmd = "typst watch " .. filepath .. " " .. output .. "\r\n"
	vim.fn.chansend(term_state.job_id, { cmd })
	term_state.typst.is_watching = true
end

map({ "n", "t" }, "<C-;>", toggle_term)
map("n", "<leader>tw", typst_watch_file)
map("n", "<leader>to", typst_open_file)
-- making current file executable
vim.api.nvim_create_user_command("Chmod", "!chmod +x %", {})
