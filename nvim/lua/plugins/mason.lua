return {
	"mason-org/mason.nvim",
	optional = true,
	opts = {
		ensure_installed = {
			"rust-analyzer",
		},
		ui = {
			border = "rounded",
		},
	},
	-- { "mason-org/mason.nvim", version = "^1.0.0" },
	-- { "mason-org/mason-lspconfig.nvim", version = "^1.0.0" },
}
