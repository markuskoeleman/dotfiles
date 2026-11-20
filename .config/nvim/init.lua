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
vim.o.timeoutlen = 1000

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
-- leader + num to switch tabs
for i = 1, 9 do
	map({ "n" }, "<leader>" .. i, "<cmd>tabnext " .. i .. "<CR>")
end

-- Custom plugins
local jump = require("jump")
local typstterm = require("typst_terminal")
local todo = require("todos")

vim.pack.add({
	{ src = "https://github.com/nvim-mini/mini.nvim" },
	{ src = "https://github.com/Julian/lean.nvim" },
})
require("mini.icons").setup()
require("mini.pick").setup()
require("mini.ai").setup()
require('mini.extra').setup()
require("mini.surround").setup()
require("mini.files").setup({
	mappings = {
		go_in_plus = "<CR>"
	},
})

vim.lsp.enable({
	"lua_ls",
	"clangd",
	"rust_analyzer",
	"pyright",
	"tinymist",
	"gdscript",
	"zls",
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

-- autocomplete
vim.opt.complete:append("o")
vim.opt.completeopt = {
	"menuone",
	"noselect",
	"popup",
	"fuzzy",
}
vim.opt.autocomplete = true

vim.cmd.colorscheme("custom-theme")

-- Make JumpLabel stand out and always the same
vim.api.nvim_set_hl(0, "JumpLabel", { bg = "#CC0066", fg = "#FFFFFF" })
-- disable greying out unsused
vim.api.nvim_set_hl(0, "DiagnosticUnnecessary", {})

-- highlight after yanking
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
})

map('n', 'gd', vim.lsp.buf.definition, { desc = "LSP Goto Definition" })

-- tinymist live preview
map("n", "<leader>tp", function()
	local clients = vim.lsp.get_clients({ name = "tinymist" })
	if #clients > 0 then
		clients[1]:exec_cmd({
			command = "tinymist.startDefaultPreview",
			title = "Tinymist Preview",
		})
	else
		print("Tinymist not active")
	end
end, { desc = "Typst Preview" })

map({ "n", "x", "o" }, "f", jump.start, {
    desc = "Jump to text",
})

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

map("n", "<leader>st", function()
	require("mini.extra").pickers.explorer({ cwd = "/home/markus/.cache/todoscratch" })
end)

map("n", "<leader>e", require("mini.files").open)

map({ "n", "t" }, "<C-;>", typstterm.toggle_term)
map("n", "<leader>tw", typstterm.typst_watch_file)
map("n", "<leader>to", typstterm.typst_open_file)

map("n", "<leader>c", todo.carry_tasks, {
	desc = "Carry unfinished tasks to today",
})

-- making current file executable
vim.api.nvim_create_user_command("Chmod", "!chmod +x %", {})
