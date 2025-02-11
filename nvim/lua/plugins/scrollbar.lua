return {
	-- https://github.com/petertriho/nvim-scrollbar
	{
		"petertriho/nvim-scrollbar",
		dependencies = {
			{ "kevinhwang91/nvim-hlslens" },
			{
				"lewis6991/gitsigns.nvim",
				opts = {
					current_line_blame = true,
				},
			},
		},
		event = "VeryLazy",
		opts = {
			handlers = {
				cursor = true,
				diagnostic = true,
				gitsigns = true,
				handle = true,
				search = true,
			},
		},
	},
}
