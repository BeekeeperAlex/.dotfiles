return {
	"snacks.nvim",
	optional = true,
	dependencies = { "HiPhish/rainbow-delimiters.nvim" },
	opts = function(_, opts)
		local rainbow_delimiters = require("rainbow-delimiters.setup")
		rainbow_delimiters.setup({})
		local rainbowDelimiterHighlight = require("rainbow-delimiters.default").highlight
		opts.indent.indent = {
			-- char = "│",
			-- char = "░",
			-- char = "▏",
			-- char = "┋",
			-- char = "┊",
			hl = rainbowDelimiterHighlight,
		}
		opts.indent.scope = {
			char = "░",
			-- char = "▓",
			hl = rainbowDelimiterHighlight,
		}
		return opts
	end,
}
