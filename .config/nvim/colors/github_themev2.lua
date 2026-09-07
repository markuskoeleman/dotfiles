local palette = {
  -- Base Canvas & Surfaces
  bg_default       = "#0D1117",
  bg_muted         = "#161B22",
  bg_inset         = "#010409",
  bg_subtle        = "#21262D",
  bg_visual        = "#1F2A38",

  -- Borders & Separators
  border_default   = "#30363D",
  border_subtle    = "#21262D",

  -- Text & UI Elements
  fg_default       = "#E6EDF3",
  fg_muted         = "#848D97",
  fg_subtle        = "#6E7681",
  fg_accent        = "#2F81F7",

  -- Status & UI Feedback
  success          = "#3FB950",
  warning          = "#D29922",
  danger           = "#F85149",
  info             = "#58A6FF",
  purple           = "#A371F7",

  -- Diff & Git Overlay
  diff_add_bg      = "#121D15",
  diff_change_bg   = "#211B10",
  diff_delete_bg   = "#221213",
  diff_text_bg     = "#1F3A22",

  -- Syntax Highlighting
  syntax = {
    keyword        = "#FF7B72", -- if, else, return
    operator       = "#FF7B72", -- +, -, =, == (Red)
    conditional    = "#FF7B72",
    constant       = "#79C0FF",
    number         = "#79C0FF",
    string         = "#A5D6FF",
    string_escape  = "#79C0FF",
    func_def       = "#D2A8FF", -- Function definitions (Purple)
    func_call      = "#E6EDF3", -- Function calls (Default Text)
    property       = "#D2A8FF", -- Fields/Properties (Purple)
    builtin        = "#79C0FF",
    variable       = "#E6EDF3",
    parameter      = "#FFA657",
    type           = "#FFA657",
    comment        = "#8B949E",
    tag            = "#7EE787",
    attribute      = "#79C0FF",
    delimiter      = "#E6EDF3",
  }
}

-- Clear existing highlights
vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end
vim.o.termguicolors = true
vim.g.colors_name = "github_dark"

local hl = vim.api.nvim_set_hl

-- Base UI & Windows
hl(0, "Normal",               { fg = palette.fg_default, bg = palette.bg_default })
hl(0, "NormalFloat",          { fg = palette.fg_default, bg = palette.bg_muted })
hl(0, "FloatBorder",          { fg = palette.border_default, bg = palette.bg_muted })
hl(0, "CursorLine",           { bg = palette.bg_subtle })
hl(0, "LineNr",               { fg = palette.fg_subtle })
hl(0, "CursorLineNr",         { fg = palette.fg_default, bold = true })
hl(0, "Visual",               { bg = palette.bg_visual })
hl(0, "WinSeparator",         { fg = palette.border_default })
hl(0, "StatusLine",           { fg = palette.fg_default, bg = palette.bg_muted })
hl(0, "StatusLineNC",         { fg = palette.fg_muted, bg = palette.bg_default })

-- Standard Vim Syntax Groups
hl(0, "Comment",              { fg = palette.syntax.comment })
hl(0, "Constant",             { fg = palette.syntax.constant })
hl(0, "String",               { fg = palette.syntax.string })
hl(0, "Number",               { fg = palette.syntax.number })
hl(0, "Boolean",              { fg = palette.syntax.constant })
hl(0, "Float",                { fg = palette.syntax.number })
hl(0, "Identifier",           { fg = palette.syntax.variable })
hl(0, "Function",             { fg = palette.syntax.func_def })
hl(0, "Statement",            { fg = palette.syntax.keyword })
hl(0, "Conditional",          { fg = palette.syntax.conditional })
hl(0, "Repeat",               { fg = palette.syntax.keyword })
hl(0, "Operator",             { fg = palette.syntax.operator })
hl(0, "Keyword",              { fg = palette.syntax.keyword })
hl(0, "Type",                 { fg = palette.syntax.type })
hl(0, "Special",              { fg = palette.syntax.string_escape })
hl(0, "Delimiter",            { fg = palette.syntax.delimiter })
hl(0, "Error",                { fg = palette.danger, bg = palette.bg_default })

-- Tree-Sitter Highlighting Groups
hl(0, "@variable",            { fg = palette.syntax.variable })
hl(0, "@variable.builtin",    { fg = palette.syntax.builtin })
hl(0, "@variable.parameter",  { fg = palette.syntax.parameter })
hl(0, "@variable.member",     { fg = palette.syntax.property }) -- Fields (Purple)
hl(0, "@property",            { fg = palette.syntax.property }) -- Fields (Purple)

hl(0, "@constant",            { fg = palette.syntax.constant })
hl(0, "@constant.builtin",    { fg = palette.syntax.builtin })

hl(0, "@string",              { fg = palette.syntax.string })
hl(0, "@string.escape",       { fg = palette.syntax.string_escape })
hl(0, "@number",              { fg = palette.syntax.number })
hl(0, "@boolean",             { fg = palette.syntax.constant })

hl(0, "@type",                { fg = palette.syntax.type })
hl(0, "@type.builtin",        { fg = palette.syntax.builtin })

hl(0, "@keyword",             { fg = palette.syntax.keyword })
hl(0, "@keyword.operator",    { fg = palette.syntax.operator }) -- Operators (Red)
hl(0, "@operator",            { fg = palette.syntax.operator }) -- Operators (Red)

hl(0, "@function",            { fg = palette.syntax.func_def }) -- Definitions (Purple)
hl(0, "@function.call",       { fg = palette.syntax.func_call }) -- Calls (Default)
hl(0, "@function.method",     { fg = palette.syntax.func_def }) -- Method defs (Purple)
hl(0, "@function.method.call",{ fg = palette.syntax.func_call }) -- Method calls (Default)

hl(0, "@punctuation.delimiter",{ fg = palette.syntax.delimiter })
hl(0, "@punctuation.bracket",  { fg = palette.syntax.delimiter })

hl(0, "@comment",             { fg = palette.syntax.comment })
hl(0, "@tag",                 { fg = palette.syntax.tag })
hl(0, "@tag.attribute",       { fg = palette.syntax.attribute })

-- LSP Semantic Tokens (Neovim 0.9+)
hl(0, "@lsp.type.class",         { link = "@type" })
hl(0, "@lsp.type.function",      { link = "@function" })
hl(0, "@lsp.type.method",        { link = "@function.method" })
hl(0, "@lsp.type.parameter",     { link = "@variable.parameter" })
hl(0, "@lsp.type.property",      { link = "@variable.member" }) -- Fields (Purple)
hl(0, "@lsp.type.variable",      { link = "@variable" })
