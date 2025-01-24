return {
	"folke/noice.nvim",
	optional = true,
	opts = function(_, opts)
		opts.presets.lsp_doc_border = true
		return opts
	end,
}
