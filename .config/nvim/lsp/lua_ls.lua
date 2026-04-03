local root_markers = {
	'.emmyrc.json',
	'.luarc.json',
	'.luarc.jsonc',
	'.luacheckrc',
	'.stylua.toml',
	'stylua.toml',
	'selene.toml',
	'selene.yml',
	'.git',
}

return {
	cmd = { 'lua-language-server' },
	filetypes = { 'lua' },
	root_markers = root_markers,
	settings = {
		Lua = {
			codeLens = { enable = true },
			hint = { enable = true, semicolon = 'Disable' },
		},
	},
}
