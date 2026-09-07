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
    keyword        = "#FF7B72", -- if, else, return, local
    operator       = "#FF7B72", -- +, -, =, == (Red)
    conditional    = "#FF7B72",
    constant       = "#79C0FF", -- true, false, nil
    number         = "#79C0FF",
    string         = "#A5D6FF",
    string_escape  = "#79C0FF",
    func_def       = "#D2A8FF", -- Function definitions (Purple)
    func_call      = "#79C0FF", -- Function calls (Blue)
    property       = "#D2A8FF", -- Fields/Properties (Purple)
    builtin        = "#79C0FF",
    variable       = "#E6EDF3", -- Standard variables (White)
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
hl(0, "@function.call",       { fg = palette.syntax.func_call }) -- Calls (Blue)
hl(0, "@function.method",     { fg = palette.syntax.func_def }) -- Method defs (Purple)
hl(0, "@function.method.call",{ fg = palette.syntax.func_call }) -- Method calls (Blue)

hl(0, "@punctuation.delimiter",{ fg = palette.syntax.delimiter })
hl(0, "@punctuation.bracket",  { fg = palette.syntax.delimiter })

hl(0, "@comment",             { fg = palette.syntax.comment })
hl(0, "@tag",                 { fg = palette.syntax.tag })
hl(0, "@tag.attribute",       { fg = palette.syntax.attribute })

-- diagnostics
hl(0, "DiagnosticError",            { fg = palette.danger })
hl(0, "DiagnosticWarn",             { fg = palette.warning })
hl(0, "DiagnosticInfo",             { fg = palette.info })
hl(0, "DiagnosticHint",             { fg = palette.fg_muted })

hl(0, "DiagnosticUnderlineError",   { undercurl = true, sp = palette.danger })
hl(0, "DiagnosticUnderlineWarn",    { undercurl = true, sp = palette.warning })
hl(0, "DiagnosticUnderlineInfo",    { undercurl = true, sp = palette.info })
hl(0, "DiagnosticUnderlineHint",    { undercurl = true, sp = palette.fg_muted })

-- ==========================================
-- 2. Search & Matches (High-Contrast Navigation)
-- ==========================================
hl(0, "Search",     { fg = palette.bg_default, bg = palette.warning })           -- Subtle yellow background for all matches
hl(0, "IncSearch",  { fg = palette.bg_default, bg = palette.syntax.parameter }) -- Bright orange focus on current match
hl(0, "CurSearch",  { fg = palette.bg_default, bg = palette.syntax.parameter })

-- ==========================================
-- 3. Auto-Completion Menu (Pmenu / CMP / Blink)
-- ==========================================
hl(0, "Pmenu",      { fg = palette.fg_default, bg = palette.bg_muted })
hl(0, "PmenuSel",   { fg = palette.fg_default, bg = palette.bg_visual, bold = true })
hl(0, "PmenuSbar",  { bg = palette.bg_subtle })
hl(0, "PmenuThumb", { bg = palette.fg_subtle })

-- ==========================================
-- LSP Semantic Tokens (Neovim 0.9+)
-- ==========================================

-- 1. Clear coarse LSP groups that overwrite granular Treesitter rules
hl(0, "@lsp.type.variable", {})  -- Prevents overwriting parameters & properties with default text
hl(0, "@lsp.type.function", {})  -- Prevents overwriting function calls with definition color
hl(0, "@lsp.type.method", {})    -- Prevents overwriting method calls with definition color
hl(0, "@lsp.type.comment", {})   -- Let Treesitter manage comments

-- 2. Explicit LSP Semantic Mappings
hl(0, "@lsp.type.namespace",     { fg = palette.fg_default })
hl(0, "@lsp.type.type",          { fg = palette.fg_default })
hl(0, "@lsp.type.class",         { fg = palette.fg_default })
hl(0, "@lsp.type.enum",          { fg = palette.fg_default })
hl(0, "@lsp.type.interface",     { fg = palette.fg_default })
hl(0, "@lsp.type.struct",        { fg = palette.fg_default })
hl(0, "@lsp.type.typeParameter", { fg = palette.fg_default })
hl(0, "@lsp.type.parameter",     { fg = palette.syntax.parameter })
hl(0, "@lsp.type.property",      { fg = palette.syntax.property })
hl(0, "@lsp.type.enumMember",    { fg = palette.syntax.constant })
hl(0, "@lsp.type.macro",         { fg = palette.syntax.constant })

-- 3. Targeted Semantic Token Modifiers (Declarations vs Calls)
hl(0, "@lsp.typemod.function.declaration", { fg = palette.syntax.func_def })
hl(0, "@lsp.typemod.function.definition",  { fg = palette.syntax.func_def })
hl(0, "@lsp.typemod.method.declaration",   { fg = palette.syntax.func_def })
hl(0, "@lsp.typemod.method.definition",    { fg = palette.syntax.func_def })

hl(0, "@lsp.typemod.function.call",        { fg = palette.syntax.func_call })
hl(0, "@lsp.typemod.method.call",          { fg = palette.syntax.func_call })

-- Readonly variables / constants
hl(0, "@lsp.typemod.variable.readonly",    { fg = palette.syntax.constant })
hl(0, "@lsp.typemod.variable.constant",    { fg = palette.syntax.constant })


-- ==========================================
-- C++ & Clangd Specific Overrides
-- ==========================================

-- 1. Preprocessor Directives (Red)
hl(0, "@keyword.directive",        { fg = palette.syntax.keyword }) -- #include
hl(0, "@keyword.directive.define", { fg = palette.syntax.keyword }) -- #define
hl(0, "@string.special.path",      { fg = palette.syntax.string })  -- <chrono>, <iostream>

-- 2. Primitive Types & Modifiers (Red instead of Orange/Blue)
hl(0, "@type.builtin",             { fg = palette.syntax.keyword }) -- int, double, void
hl(0, "@keyword.modifier",         { fg = palette.syntax.keyword }) -- const, static
hl(0, "@keyword.type",             { fg = palette.syntax.keyword }) -- struct, class, enum

-- 4. Variables & Constants (White instead of Blue)
hl(0, "@variable",                 { fg = palette.fg_default })     -- Standard variables
hl(0, "@constant",                 { fg = palette.fg_default })     -- Prevent ALL constants from turning blue
hl(0, "@constant.builtin",         { fg = palette.syntax.constant })-- Keep true/false/nil blue

-- 5. Clangd LSP Semantic Token Overrides
-- Clangd aggressively overrides treesitter variables. We clear these specific
-- LSP tokens so Neovim falls back to standard white text for variables.
hl(0, "@lsp.type.variable",           {}) -- Clear Clangd standard variables
hl(0, "@lsp.typemod.variable.readonly", {}) -- Clear Clangd const variables (gates, lanes)
hl(0, "@lsp.typemod.variable.global",   {}) -- Clear Clangd global scope variables
hl(0, "@lsp.type.property",           {}) -- Clear Clangd struct fields
hl(0, "@lsp.type.type",               {}) -- Let Treesitter handle types (fixes blue structs)


-- ==========================================
-- Mini.pick Refined Selection & Matches
-- ==========================================

-- Picker Canvas & Window
hl(0, "MiniPickNormal",       { fg = palette.fg_default, bg = palette.bg_muted })
hl(0, "MiniPickBorder",       { fg = palette.border_default, bg = palette.bg_muted })
hl(0, "MiniPickPrompt",       { fg = palette.fg_accent, bold = true })

-- Selection Background (Keeps text white while highlighting the row)
hl(0, "CursorLine",           { bg = palette.bg_visual })

-- Matched Characters Only (Orange matched letters)
hl(0, "MiniPickMatchCurrent", { bold = true }) -- Orange matched letter on active row (#FFA657)
hl(0, "MiniPickMatchRanges",  { fg = palette.syntax.parameter, bold = true }) -- Orange matched letters on inactive rows (#FFA657)

-- testing
hl(0, "type", { fg = palette.fg_default })
hl(0, "@type",             { fg = palette.fg_default })
hl(0, "@type.builtin",     { fg = palette.fg_default })
hl(0, "@lsp.type.type",    { fg = palette.fg_default })
hl(0, "@lsp.type.class",   { fg = palette.fg_default })
hl(0, "@lsp.type.struct",  { fg = palette.fg_default })
hl(0, "@lsp.type.enum",    { fg = palette.fg_default })
hl(0, "@lsp.type.interface",{ fg = palette.fg_default })

hl(0, "@lsp.type.operator", {fg = palette.syntax.operator})
