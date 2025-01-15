return {
	"nvim-lualine/lualine.nvim",
	optional = true,
	opts = function(_, opts)
		opts.sections.lualine_z = {
			{
				"datetime",
				style = "  %I:%M %p",
			},
		}
	end,
}
