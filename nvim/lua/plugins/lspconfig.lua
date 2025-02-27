return {
	{
		"neovim/nvim-lspconfig",
		opts = {
			diagnostics = {
				-- virtual_text = false,
				-- virtual_lines = true,
				float = {
					header = false,
					border = "rounded",
				},
			},
			inlay_hints = { enabled = false },
			setup = {
				-- Hack to suppress encoding error with clangd.
				clangd = function(_, opts)
					opts.capabilities.offsetEncoding = { "utf-16" }
				end,
			},
		},
	},
}
