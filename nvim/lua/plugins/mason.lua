return {
	"williamboman/mason.nvim",
	optional = true,
	opts = {
		ensure_installed = {
			"rust-analyzer",
		},
		ui = {
			border = "rounded",
		},
	},
}
