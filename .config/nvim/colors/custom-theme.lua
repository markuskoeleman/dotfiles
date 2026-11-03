local palette = {
	-- Base Canvas & Surfaces
	bg_default     = "#0D1117",
	bg_muted       = "#161B22",
	bg_inset       = "#010409",
	bg_subtle      = "#21262D",
	bg_visual      = "#1F2A38",

	-- Borders & Separators
	border_default = "#30363D",
	border_subtle  = "#21262D",

	-- Text & UI Elements
	fg_default     = "#E6EDF3",
	fg_muted       = "#848D97",
	fg_subtle      = "#6E7681",
	fg_accent      = "#2F81F7",

	-- Status & UI Feedback
	success        = "#3FB950",
	warning        = "#D29922",
	danger         = "#F85149",
	info           = "#58A6FF",
	purple         = "#A371F7",

	-- Diff & Git Overlay
	diff_add_bg    = "#121D15",
	diff_change_bg = "#211B10",
	diff_delete_bg = "#221213",
	diff_text_bg   = "#1F3A22",

	-- Syntax Highlighting
	syntax         = {
		keyword       = "#FF7B72",
		operator      = "#FF7B72",
		conditional   = "#FF7B72",
		constant      = "#79C0FF",
		number        = "#79C0FF",
		string        = "#A5D6FF",
		string_escape = "#79C0FF",
		func_def      = "#D2A8FF",
		func_call     = "#79C0FF",
		property      = "#D2A8FF",
		builtin       = "#79C0FF",
		variable      = "#E6EDF3",
		parameter     = "#FFA657",
		type          = "#E6EDF3",
		comment       = "#8B949E",
		tag           = "#7EE787",
		attribute     = "#79C0FF",
		delimiter     = "#E6EDF3",
	},
}

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
	vim.cmd("syntax reset")
end
vim.o.termguicolors = true

local hl = vim.api.nvim_set_hl
local function set(groups)
	for group, opts in pairs(groups) do
		hl(0, group, opts)
	end
end

-- Editor UI
set({
	Normal       = { fg = palette.fg_default, bg = palette.bg_default },
	NormalFloat  = { fg = palette.fg_default, bg = palette.bg_muted },
	FloatBorder  = { fg = palette.border_default, bg = palette.bg_muted },
	CursorLine   = { bg = palette.bg_subtle },
	LineNr       = { fg = palette.fg_subtle },
	CursorLineNr = { fg = palette.fg_default, bold = true },
	Visual       = { bg = palette.bg_visual },
	WinSeparator = { fg = palette.border_default },
	StatusLine   = { fg = palette.fg_default, bg = palette.bg_muted },
	StatusLineNC = { fg = palette.fg_muted, bg = palette.bg_default },
})

-- Built-in Vim syntax (no Tree-sitter required)
set({
	Comment     = { fg = palette.syntax.comment },
	Constant    = { fg = palette.syntax.constant },
	String      = { fg = palette.syntax.string },
	Number      = { fg = palette.syntax.number },
	Boolean     = { fg = palette.syntax.constant },
	Float       = { fg = palette.syntax.number },
	Identifier  = { fg = palette.syntax.variable },
	Function    = { fg = palette.syntax.func_def },
	Statement   = { fg = palette.syntax.keyword },
	Conditional = { fg = palette.syntax.conditional },
	Repeat      = { fg = palette.syntax.keyword },
	Operator    = { fg = palette.syntax.operator },
	Keyword     = { fg = palette.syntax.keyword },
	Type        = { fg = palette.syntax.type },
	Special     = { fg = palette.syntax.string_escape },
	Delimiter   = { fg = palette.syntax.delimiter },
	Error       = { fg = palette.danger, bg = palette.bg_default },
	PreProc     = { fg = palette.syntax.keyword },
})

-- LSP semantic tokens (independent of Tree-sitter)
set({
	["@lsp.type.variable"]                = { fg = palette.syntax.variable },
	["@lsp.type.parameter"]               = { fg = palette.syntax.parameter },
	["@lsp.type.property"]                = { fg = palette.syntax.property },
	["@lsp.type.function"]                = { fg = palette.syntax.func_call },
	["@lsp.type.method"]                  = { fg = palette.syntax.func_call },
	["@lsp.type.namespace"]               = { fg = palette.fg_default },
	["@lsp.type.type"]                    = { fg = palette.fg_default },
	["@lsp.type.class"]                   = { fg = palette.fg_default },
	["@lsp.type.enum"]                    = { fg = palette.fg_default },
	["@lsp.type.interface"]               = { fg = palette.fg_default },
	["@lsp.type.struct"]                  = { fg = palette.fg_default },
	["@lsp.type.typeParameter"]           = { fg = palette.fg_default },
	["@lsp.type.enumMember"]              = { fg = palette.syntax.constant },
	["@lsp.type.macro"]                   = { fg = palette.syntax.constant },
	["@lsp.type.keyword"]                 = { fg = palette.syntax.keyword },
	["@lsp.type.operator"]                = { fg = palette.syntax.operator },
	["@lsp.type.string"]                  = { fg = palette.syntax.string },
	["@lsp.type.number"]                  = { fg = palette.syntax.number },
	["@lsp.type.comment"]                 = {}, -- Let Vim's Comment group control comments.

	["@lsp.typemod.function.declaration"] = { fg = palette.syntax.func_def },
	["@lsp.typemod.function.definition"]  = { fg = palette.syntax.func_def },
	["@lsp.typemod.method.declaration"]   = { fg = palette.syntax.func_def },
	["@lsp.typemod.method.definition"]    = { fg = palette.syntax.func_def },
	["@lsp.typemod.variable.readonly"]    = { fg = palette.syntax.constant },
})

-- Keep C++ properties (for example, struct fields) neutral.
set({
	["@lsp.type.property.cpp"] = { fg = palette.fg_default },
	["@lsp.type.operator.cpp"] = {
		fg = palette.syntax.operator
	},
})


-- Diagnostics
set({
	DiagnosticError          = { fg = palette.danger },
	DiagnosticWarn           = { fg = palette.warning },
	DiagnosticInfo           = { fg = palette.info },
	DiagnosticHint           = { fg = palette.fg_muted },

	DiagnosticUnderlineError = { undercurl = true, sp = palette.danger },
	DiagnosticUnderlineWarn  = { undercurl = true, sp = palette.warning },
	DiagnosticUnderlineInfo  = { undercurl = true, sp = palette.info },
	DiagnosticUnderlineHint  = { undercurl = true, sp = palette.fg_muted },
})

-- Search
set({
	Search    = { fg = palette.bg_default, bg = palette.warning },
	IncSearch = { fg = palette.bg_default, bg = palette.syntax.parameter },
	CurSearch = { fg = palette.bg_default, bg = palette.syntax.parameter },
})

-- Completion menu
set({
	Pmenu      = { fg = palette.fg_default, bg = palette.bg_muted },
	PmenuSel   = { fg = palette.fg_default, bg = palette.bg_visual, bold = true },
	PmenuSbar  = { bg = palette.bg_subtle },
	PmenuThumb = { bg = palette.fg_subtle },
})

-- Diff and Gitsigns
set({
	DiffAdd        = { fg = palette.success, bg = palette.diff_add_bg },
	DiffChange     = { fg = palette.warning, bg = palette.diff_change_bg },
	DiffDelete     = { fg = palette.danger, bg = palette.diff_delete_bg },
	DiffText       = { bg = palette.diff_text_bg },

	GitSignsAdd    = { fg = palette.success },
	GitSignsChange = { fg = palette.warning },
	GitSignsDelete = { fg = palette.danger },
})

-- Mini.pick
set({
	MiniPickNormal       = { fg = palette.fg_default, bg = palette.bg_muted },
	MiniPickBorder       = { fg = palette.border_default, bg = palette.bg_muted },
	MiniPickPrompt       = { fg = palette.fg_accent, bold = true },
	MiniPickMatchCurrent = { bold = true },
	MiniPickMatchRanges  = { fg = palette.syntax.parameter, bold = true },
})

-- potentially keeping this highlight a variable only when it is defined
hl(0, "@lsp.typemod.variable.definition", {
    fg = palette.syntax.func_def
})
